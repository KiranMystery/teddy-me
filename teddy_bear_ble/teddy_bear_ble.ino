/*
  Teddy bear controller for ESP32 - BLUETOOTH (BLE) version
  ------------------------------------------------------------
  The bear advertises as "Teddy". The control page (app-ble.html)
  connects with Web Bluetooth and writes to two characteristics:

    MOTOR  write 1 = buzz, 0 = stop  (app re-sends 1 every 400 ms while held)
    LED    write 1 = on,   0 = off   (notifies the app when it changes)

  Wiring (see circuit.svg / circuit-led.svg):
    GPIO 25 -> 220R -> LED -> GND
    GPIO 26 -> 1k -> NPN base; motor between 3V3 and collector;
               emitter to GND; 1N4148 across the motor (stripe to 3V3)

  Flash it like the WiFi sketch: board "ESP32 Dev Module", Upload.
  The BLE library ships with the ESP32 core. (If the upload complains the
  sketch is too big, choose Tools -> Partition Scheme -> "Huge APP".)
*/

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ---------- settings ----------
const char* DEVICE_NAME = "Teddy";

const int LED_PIN   = 25;
const int MOTOR_PIN = 26;

// Safety: if the phone stops saying "hold" for this long, the motor stops.
const unsigned long MOTOR_TIMEOUT_MS = 1200;

// These IDs must match the ones in app-ble.html
#define SERVICE_UUID "0e7a1000-7edd-4bea-a000-5eed12345678"
#define MOTOR_UUID   "0e7a1001-7edd-4bea-a000-5eed12345678"
#define LED_UUID     "0e7a1002-7edd-4bea-a000-5eed12345678"
// ------------------------------

BLEServer*         server   = nullptr;
BLECharacteristic* motorChr = nullptr;
BLECharacteristic* ledChr   = nullptr;

bool ledOn   = false;
bool motorOn = false;
bool connected = false;
bool restartAdvertising = false;
unsigned long motorLastPing = 0;

void setLed(bool on) {
  ledOn = on;
  digitalWrite(LED_PIN, on ? HIGH : LOW);
  if (ledChr) {
    uint8_t v = on ? 1 : 0;
    ledChr->setValue(&v, 1);
    if (connected) ledChr->notify();
  }
}

void setMotor(bool on) {
  motorOn = on;
  digitalWrite(MOTOR_PIN, on ? HIGH : LOW);
}

// first byte written: 0 = off, anything else = on
static bool firstByteIsOn(BLECharacteristic* c) {
  return c->getLength() > 0 && c->getData()[0] != 0;
}

class MotorCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) {
    if (firstByteIsOn(c)) {
      motorLastPing = millis();
      if (!motorOn) setMotor(true);
    } else {
      setMotor(false);
    }
  }
};

class LedCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) {
    setLed(firstByteIsOn(c));
  }
};

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) {
    connected = true;
    Serial.println("Phone connected");
  }
  void onDisconnect(BLEServer*) {
    connected = false;
    setMotor(false);            // never leave it buzzing after a drop-out
    restartAdvertising = true;  // done in loop(), not inside the callback
    Serial.println("Phone disconnected");
  }
};

void setup() {
  Serial.begin(115200);
  delay(200);

  pinMode(LED_PIN, OUTPUT);
  pinMode(MOTOR_PIN, OUTPUT);
  setMotor(false);
  digitalWrite(LED_PIN, LOW);

  BLEDevice::init(DEVICE_NAME);
  server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* svc = server->createService(SERVICE_UUID);

  motorChr = svc->createCharacteristic(
      MOTOR_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  motorChr->setCallbacks(new MotorCallbacks());

  ledChr = svc->createCharacteristic(
      LED_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE |
      BLECharacteristic::PROPERTY_NOTIFY);
  ledChr->setCallbacks(new LedCallbacks());
  ledChr->addDescriptor(new BLE2902());

  svc->start();
  setLed(false);

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);   // helps iPhone connect quickly
  adv->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.printf("Advertising as \"%s\"\n", DEVICE_NAME);

  // quick "hello" so you know it booted
  setLed(true);  setMotor(true);  delay(150);
  setLed(false); setMotor(false);
}

void loop() {
  if (restartAdvertising) {
    restartAdvertising = false;
    delay(300);
    BLEDevice::startAdvertising();
    Serial.println("Advertising again");
  }

  // Safety timeout: stop the motor if the phone went quiet.
  if (motorOn && millis() - motorLastPing > MOTOR_TIMEOUT_MS) {
    setMotor(false);
  }
  delay(10);
}
