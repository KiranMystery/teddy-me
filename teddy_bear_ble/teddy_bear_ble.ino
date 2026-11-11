/*
  Teddy bear controller for ESP32 - BLUETOOTH (BLE) version
  ------------------------------------------------------------
  The bear advertises as "Teddy". The control page (app-ble.html)
  connects with Web Bluetooth and writes to two characteristics:

    MOTOR  write 1 = buzz, 0 = stop  (app re-sends 1 every 400 ms while held)
    LED    write 0 = off, 1 = slow pulse ("breathing"), 2 = steady on
           (notifies the app with the same value when it changes)

  The pulse is done in software with the ESP32's PWM (LEDC) on the LED pin,
  so the LED circuit is unchanged: GPIO 25 -> 220R -> LED -> GND.

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

// LED pulse: one full breath (dark -> bright -> dark) takes this long.
const unsigned long PULSE_PERIOD_MS = 3000;
const int PWM_FREQ_HZ = 5000;   // well above anything the eye can see
const int PWM_BITS    = 8;      // duty 0..255

enum LedMode : uint8_t { LED_OFF = 0, LED_PULSE = 1, LED_STEADY = 2 };

// These IDs must match the ones in app-ble.html
#define SERVICE_UUID "0e7a1000-7edd-4bea-a000-5eed12345678"
#define MOTOR_UUID   "0e7a1001-7edd-4bea-a000-5eed12345678"
#define LED_UUID     "0e7a1002-7edd-4bea-a000-5eed12345678"
// ------------------------------

BLEServer*         server   = nullptr;
BLECharacteristic* motorChr = nullptr;
BLECharacteristic* ledChr   = nullptr;

LedMode ledMode = LED_OFF;
unsigned long pulseStart = 0;
bool motorOn = false;
bool connected = false;
bool restartAdvertising = false;
unsigned long motorLastPing = 0;

// Brightness 0..255, gamma-corrected so the fade looks even to the eye.
void ledWrite(uint8_t level) {
  uint32_t duty = ((uint32_t)level * level) / 255;
  ledcWrite(LED_PIN, duty);
}

void setLed(LedMode mode) {
  ledMode = mode;
  const char* name = mode == LED_OFF ? "off" : mode == LED_PULSE ? "PULSE" : "ON";
  Serial.printf("LED %s (GPIO %d)\n", name, LED_PIN);
  if (mode == LED_PULSE) pulseStart = millis();
  ledWrite(mode == LED_STEADY ? 255 : 0);   // pulse starts dark and breathes in
  if (ledChr) {
    uint8_t v = (uint8_t)mode;
    ledChr->setValue(&v, 1);
    if (connected) ledChr->notify();
  }
}

// Called every loop: computes the breathing brightness while in pulse mode.
void updatePulse() {
  if (ledMode != LED_PULSE) return;
  unsigned long t = (millis() - pulseStart) % PULSE_PERIOD_MS;
  float phase = (float)t / (float)PULSE_PERIOD_MS;          // 0..1
  float x = 0.5f - 0.5f * cosf(phase * 2.0f * PI);          // 0 -> 1 -> 0, smooth
  ledWrite((uint8_t)(x * 255.0f));
}

void setMotor(bool on) {
  if (on != motorOn) Serial.printf("motor %s (GPIO %d)\n", on ? "ON" : "off", MOTOR_PIN);
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
    if (c->getLength() == 0) return;
    uint8_t v = c->getData()[0];
    setLed(v == 0 ? LED_OFF : v == 2 ? LED_STEADY : LED_PULSE);  // 1 (or anything else) = pulse
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

  ledcAttach(LED_PIN, PWM_FREQ_HZ, PWM_BITS);   // PWM on the LED pin (ESP32 core 3.x API)
  ledWrite(0);
  pinMode(MOTOR_PIN, OUTPUT);
  setMotor(false);

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
  setLed(LED_OFF);

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);   // helps iPhone connect quickly
  adv->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.printf("Advertising as \"%s\"\n", DEVICE_NAME);

  // quick "hello" so you know it booted
  setLed(LED_STEADY); setMotor(true);  delay(150);
  setLed(LED_OFF);    setMotor(false);
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

  updatePulse();
  delay(10);
}
