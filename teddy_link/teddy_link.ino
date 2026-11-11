/*
  Teddy LINK firmware for ESP32 - two bears that feel each other
  ------------------------------------------------------------------
  Same circuit as before (GPIO 25 -> 220R -> LED -> GND, GPIO 26 -> 1k ->
  NPN -> motor). Two ways of running, picked automatically at boot:

  1. SETUP mode (Bluetooth).  No WiFi details saved yet, or WiFi failed.
     Advertises as "Teddy". The setup page (setup.html) connects with Web
     Bluetooth and writes "ssid<TAB>password<TAB>paircode" to the SETUP
     characteristic. The bear saves it and reboots into LINK mode.
     The MOTOR / LED characteristics still work here, so the plain
     Bluetooth app (app-ble.html) controls the bear directly in this mode.

  2. LINK mode (WiFi + MQTT).  Joins the saved WiFi and an MQTT broker.
     Every bear with the same pair code listens on  teddy/<pair>/touch.
     A message with "to" is for that one bear; a message without "to" is
     for every bear except the sender (bear-to-bear, e.g. a paw sensor).
     The linked app (app-link.html) publishes, for any bear it shows:
        {"from":"app","to":"<bearId>","motor":1}   while the paw is held (every 400 ms)
        {"from":"app","to":"<bearId>","motor":0}   on release
        {"from":"app","to":"<bearId>","led":1}     0 off, 1 slow pulse, 2 steady
     Each bear publishes its own state (retained) on teddy/<pair>/state/<id>
     and listens for  teddy/<pair>/cmd/<id>  with {"cmd":"setup"} to forget
     WiFi and go back to SETUP mode.

  Bear id = last 3 bytes of the WiFi MAC, e.g. "7c2a9f". Read it over
  Bluetooth from the INFO characteristic, or from the serial monitor.

  Needs the PubSubClient library (arduino-cli lib install PubSubClient).
  Flash with  ./flash.sh link   (Partition scheme: Huge APP).
*/

#include <Preferences.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ---------- settings ----------
const char* DEVICE_NAME = "Teddy";

const int LED_PIN   = 25;
const int MOTOR_PIN = 26;

const unsigned long MOTOR_TIMEOUT_MS = 1200;   // stop if "hold" messages stop
const unsigned long PULSE_PERIOD_MS  = 3000;   // one slow breath
const int PWM_FREQ_HZ = 5000;
const int PWM_BITS    = 8;

// Public test broker. Anyone who knows your pair code can poke your bear,
// so use a long random code, or point this at your own broker later.
const char* MQTT_HOST = "broker.emqx.io";
const int   MQTT_PORT = 1883;

const unsigned long WIFI_TIMEOUT_MS   = 20000; // then fall back to SETUP mode
const unsigned long MQTT_RETRY_MS     = 5000;
const unsigned long STATE_PERIOD_MS   = 30000; // heartbeat / presence

// Must match setup.html and app-ble.html
#define SERVICE_UUID "0e7a1000-7edd-4bea-a000-5eed12345678"
#define MOTOR_UUID   "0e7a1001-7edd-4bea-a000-5eed12345678"
#define LED_UUID     "0e7a1002-7edd-4bea-a000-5eed12345678"
#define SETUP_UUID   "0e7a1003-7edd-4bea-a000-5eed12345678"  // write "ssid\tpass\tpair" or "reset"
#define INFO_UUID    "0e7a1004-7edd-4bea-a000-5eed12345678"  // read: "id=xxxxxx mode=setup wifi=none|fail pair=..."
// ------------------------------

enum LedMode : uint8_t { LED_OFF = 0, LED_PULSE = 1, LED_STEADY = 2 };
enum RunMode { MODE_SETUP, MODE_LINK };

Preferences prefs;
RunMode  runMode = MODE_SETUP;
String   bearId, ssid, pass, pair;
bool     wifiFailed = false;

LedMode ledMode = LED_OFF;
unsigned long pulseStart = 0;
bool motorOn = false;
unsigned long motorLastPing = 0;

// BLE (setup mode)
BLEServer*         server   = nullptr;
BLECharacteristic* motorChr = nullptr;
BLECharacteristic* ledChr   = nullptr;
BLECharacteristic* setupChr = nullptr;
BLECharacteristic* infoChr  = nullptr;
bool connected = false;
bool restartAdvertising = false;
bool rebootRequested = false;

// MQTT (link mode)
WiFiClient   net;
PubSubClient mqtt(net);
String topicTouch, topicState, topicCmd;
unsigned long lastMqttTry = 0, lastState = 0;
bool stateDirty = true;

// ---------- LED / motor ----------
void ledWrite(uint8_t level) {                // gamma corrected 0..255
  ledcWrite(LED_PIN, ((uint32_t)level * level) / 255);
}

void setLed(LedMode mode) {
  ledMode = mode;
  const char* name = mode == LED_OFF ? "off" : mode == LED_PULSE ? "PULSE" : "ON";
  Serial.printf("LED %s (GPIO %d)\n", name, LED_PIN);
  if (mode == LED_PULSE) pulseStart = millis();
  ledWrite(mode == LED_STEADY ? 255 : 0);
  if (ledChr) {
    uint8_t v = (uint8_t)mode;
    ledChr->setValue(&v, 1);
    if (connected) ledChr->notify();
  }
  stateDirty = true;
}

void updatePulse() {
  if (ledMode != LED_PULSE) return;
  unsigned long t = (millis() - pulseStart) % PULSE_PERIOD_MS;
  float x = 0.5f - 0.5f * cosf((float)t / (float)PULSE_PERIOD_MS * 2.0f * PI);
  ledWrite((uint8_t)(x * 255.0f));
}

void setMotor(bool on) {
  if (on != motorOn) Serial.printf("motor %s (GPIO %d)\n", on ? "ON" : "off", MOTOR_PIN);
  motorOn = on;
  digitalWrite(MOTOR_PIN, on ? HIGH : LOW);
}

void motorPing(bool on) {
  if (on) { motorLastPing = millis(); if (!motorOn) setMotor(true); }
  else setMotor(false);
}

LedMode ledModeFrom(int v) { return v == 0 ? LED_OFF : v == 2 ? LED_STEADY : LED_PULSE; }

// ---------- tiny JSON helpers (flat objects only) ----------
int jsonInt(const String& s, const char* key, int def) {
  String k = String("\"") + key + "\"";
  int i = s.indexOf(k); if (i < 0) return def;
  i = s.indexOf(':', i); if (i < 0) return def;
  return s.substring(i + 1).toInt();
}
String jsonStr(const String& s, const char* key) {
  String k = String("\"") + key + "\"";
  int i = s.indexOf(k); if (i < 0) return "";
  i = s.indexOf(':', i); if (i < 0) return "";
  int q1 = s.indexOf('"', i); if (q1 < 0) return "";
  int q2 = s.indexOf('"', q1 + 1); if (q2 < 0) return "";
  return s.substring(q1 + 1, q2);
}

// ---------- settings ----------
void loadSettings() {
  prefs.begin("teddy", true);
  ssid = prefs.getString("ssid", "");
  pass = prefs.getString("pass", "");
  pair = prefs.getString("pair", "");
  prefs.end();
}
void saveSettings(const String& s, const String& p, const String& code) {
  prefs.begin("teddy", false);
  prefs.putString("ssid", s);
  prefs.putString("pass", p);
  prefs.putString("pair", code);
  prefs.end();
}
void clearSettings() {
  prefs.begin("teddy", false);
  prefs.clear();
  prefs.end();
}

String infoString() {
  String s = "id=" + bearId + " mode=" + (runMode == MODE_LINK ? "link" : "setup");
  s += " wifi=" + String(ssid.length() == 0 ? "none" : wifiFailed ? "fail" : "ok");
  s += " pair=" + pair;
  return s;
}

// ---------- BLE callbacks ----------
static bool firstByteIsOn(BLECharacteristic* c) {
  return c->getLength() > 0 && c->getData()[0] != 0;
}

class MotorCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) { motorPing(firstByteIsOn(c)); }
};

class LedCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) {
    if (c->getLength() == 0) return;
    setLed(ledModeFrom(c->getData()[0]));
  }
};

class SetupCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) {
    String v = String((const char*)c->getData()).substring(0, c->getLength());
    v.trim();
    if (v == "reset") {
      clearSettings();
      Serial.println("WiFi settings cleared");
      infoChr->setValue("ok=reset");
      return;
    }
    int t1 = v.indexOf('\t');
    int t2 = v.indexOf('\t', t1 + 1);
    if (t1 < 1 || t2 < 0) {
      Serial.println("setup: bad format, want ssid<TAB>password<TAB>pair");
      infoChr->setValue("error=format");
      return;
    }
    String s = v.substring(0, t1), p = v.substring(t1 + 1, t2), code = v.substring(t2 + 1);
    code.trim();
    if (code.length() < 4) { infoChr->setValue("error=pair"); return; }
    saveSettings(s, p, code);
    Serial.printf("setup: ssid=\"%s\" pair=%s, rebooting into LINK mode\n", s.c_str(), code.c_str());
    infoChr->setValue("ok=saved id=" + bearId);
    if (connected) infoChr->notify();
    rebootRequested = true;   // done in loop(), after the notify gets out
  }
};

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) { connected = true; Serial.println("Phone connected"); }
  void onDisconnect(BLEServer*) {
    connected = false;
    setMotor(false);
    restartAdvertising = true;
    Serial.println("Phone disconnected");
  }
};

void startSetupMode() {
  runMode = MODE_SETUP;
  BLEDevice::init(DEVICE_NAME);
  BLEDevice::setMTU(256);
  server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  BLEService* svc = server->createService(BLEUUID(SERVICE_UUID), 20);

  motorChr = svc->createCharacteristic(MOTOR_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  motorChr->setCallbacks(new MotorCallbacks());

  ledChr = svc->createCharacteristic(LED_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);
  ledChr->setCallbacks(new LedCallbacks());
  ledChr->addDescriptor(new BLE2902());

  setupChr = svc->createCharacteristic(SETUP_UUID, BLECharacteristic::PROPERTY_WRITE);
  setupChr->setCallbacks(new SetupCallbacks());

  infoChr = svc->createCharacteristic(INFO_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  infoChr->setValue(infoString().c_str());
  infoChr->addDescriptor(new BLE2902());

  svc->start();
  setLed(LED_OFF);

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);
  adv->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.printf("SETUP mode: advertising as \"%s\" (%s)\n", DEVICE_NAME, infoString().c_str());
}

// ---------- MQTT ----------
void publishState() {
  if (!mqtt.connected()) return;
  String s = "{\"id\":\"" + bearId + "\",\"online\":1,\"led\":" + String((int)ledMode) + "}";
  mqtt.publish(topicState.c_str(), s.c_str(), true);
  lastState = millis();
  stateDirty = false;
}

void onMqtt(char* topic, byte* payload, unsigned int len) {
  String t(topic);
  String msg; msg.reserve(len);
  for (unsigned int i = 0; i < len; i++) msg += (char)payload[i];

  if (t == topicTouch) {
    String from = jsonStr(msg, "from");
    String to   = jsonStr(msg, "to");
    if (to.length() > 0) { if (to != bearId) return; }   // addressed to another bear
    else if (from == bearId) return;                     // broadcast from myself, ignore
    int m = jsonInt(msg, "motor", -1);
    int l = jsonInt(msg, "led", -1);
    if (m >= 0) motorPing(m != 0);
    if (l >= 0) setLed(ledModeFrom(l));
  } else if (t == topicCmd) {
    String cmd = jsonStr(msg, "cmd");
    if (cmd == "setup") {
      Serial.println("cmd: setup -> clearing WiFi and rebooting");
      clearSettings();
      delay(200);
      ESP.restart();
    } else if (cmd == "ping") {
      stateDirty = true;
    }
  }
}

bool mqttConnect() {
  String clientId = "teddy-" + bearId;
  String will = "{\"id\":\"" + bearId + "\",\"online\":0}";
  if (mqtt.connect(clientId.c_str(), topicState.c_str(), 0, true, will.c_str())) {
    mqtt.subscribe(topicTouch.c_str());
    mqtt.subscribe(topicCmd.c_str());
    Serial.printf("MQTT connected to %s as %s\n", MQTT_HOST, clientId.c_str());
    publishState();
    return true;
  }
  Serial.printf("MQTT connect failed, rc=%d\n", mqtt.state());
  return false;
}

bool startLinkMode() {
  Serial.printf("LINK mode: joining WiFi \"%s\"...\n", ssid.c_str());
  WiFi.mode(WIFI_STA);
  WiFi.setHostname(("teddy-" + bearId).c_str());
  WiFi.begin(ssid.c_str(), pass.c_str());
  unsigned long t0 = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - t0 < WIFI_TIMEOUT_MS) {
    // blink while connecting
    ledWrite(((millis() / 250) % 2) ? 60 : 0);
    delay(50);
  }
  ledWrite(0);
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi failed. Falling back to SETUP mode (Bluetooth).");
    WiFi.disconnect(true);
    WiFi.mode(WIFI_OFF);
    return false;
  }
  Serial.printf("WiFi ok, IP %s\n", WiFi.localIP().toString().c_str());
  runMode = MODE_LINK;

  topicTouch = "teddy/" + pair + "/touch";
  topicState = "teddy/" + pair + "/state/" + bearId;
  topicCmd   = "teddy/" + pair + "/cmd/" + bearId;
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(onMqtt);
  mqtt.setBufferSize(512);
  mqttConnect();
  return true;
}

// ---------- setup / loop ----------
void setup() {
  Serial.begin(115200);
  delay(200);

  ledcAttach(LED_PIN, PWM_FREQ_HZ, PWM_BITS);
  ledWrite(0);
  pinMode(MOTOR_PIN, OUTPUT);
  setMotor(false);

  uint8_t mac[6];
  WiFi.macAddress(mac);
  char idbuf[8];
  snprintf(idbuf, sizeof(idbuf), "%02x%02x%02x", mac[3], mac[4], mac[5]);
  bearId = idbuf;

  loadSettings();
  Serial.printf("Teddy %s, pair=%s\n", bearId.c_str(), pair.length() ? pair.c_str() : "(none)");

  bool linked = false;
  if (ssid.length() > 0) {
    linked = startLinkMode();
    wifiFailed = !linked;
  }
  if (!linked) startSetupMode();

  // hello
  setLed(LED_STEADY); setMotor(true);  delay(150);
  setLed(LED_OFF);    setMotor(false);
}

void loop() {
  if (runMode == MODE_SETUP) {
    if (rebootRequested) { delay(500); ESP.restart(); }
    if (restartAdvertising) {
      restartAdvertising = false;
      delay(300);
      BLEDevice::startAdvertising();
      Serial.println("Advertising again");
    }
  } else {
    if (WiFi.status() != WL_CONNECTED) {
      // WiFi.begin() auto-reconnects; just keep the motor safe meanwhile
    } else if (!mqtt.connected()) {
      if (millis() - lastMqttTry > MQTT_RETRY_MS) { lastMqttTry = millis(); mqttConnect(); }
    } else {
      mqtt.loop();
      if (stateDirty || millis() - lastState > STATE_PERIOD_MS) publishState();
    }
  }

  // serial: type "reset" to forget WiFi
  if (Serial.available()) {
    String line = Serial.readStringUntil('\n'); line.trim();
    if (line == "reset") { clearSettings(); Serial.println("cleared, rebooting"); delay(200); ESP.restart(); }
    else if (line == "info") Serial.println(infoString());
  }

  if (motorOn && millis() - motorLastPing > MOTOR_TIMEOUT_MS) setMotor(false);
  updatePulse();
  delay(10);
}
