/*
  Teddy bear controller for ESP32
  ------------------------------------------------------------
  Serves a little web app over WiFi. Open it on your phone and
  you get a "hold to buzz" button for the vibration motor and
  a toggle for the LED.

  Wiring (see circuit.svg):
    GPIO 25 -> 220R -> LED -> GND
    GPIO 26 -> 1k -> NPN base; motor between 3V3 and collector;
               emitter to GND; 1N4148 across the motor (stripe to 3V3)

  How to use:
    1. Arduino IDE -> Boards Manager -> install "esp32" by Espressif.
    2. Pick your board (e.g. "ESP32 Dev Module"), choose the port, Upload.
    3. Open Serial Monitor at 115200 to see the address.
    4. HOTSPOT MODE (default): on your phone join WiFi "TeddyBear"
       (password below) and open http://192.168.4.1
       HOME WIFI MODE: fill in HOME_SSID / HOME_PASS, then open
       http://teddy.local (or the IP printed in Serial Monitor).

  Libraries used (WiFi, WebServer, ESPmDNS) all ship with the ESP32 core.
*/

#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include "driver/gpio.h"

// ---------- settings ----------
const char* HOME_SSID = "";            // leave blank to use hotspot mode
const char* HOME_PASS = "";
const char* AP_SSID   = "TeddyBear";   // hotspot name the bear creates
const char* AP_PASS   = "cuddles123";  // at least 8 characters
const char* MDNS_NAME = "teddy";       // -> http://teddy.local in home wifi mode

const int LED_PIN   = 25;   // most DevKit boards also have a built-in LED on GPIO 2 - handy for testing with no parts
const int MOTOR_PIN = 26;

// No 220R resistor for the LED? Set this true. The pin is then told to drive
// weakly (about 5 mA instead of 20 mA), which does the resistor's job well
// enough for a hobby project. Blue/white LEDs are fine either way at 3.3 V.
const bool LED_NO_RESISTOR = false;

// Safety: if the phone stops saying "hold" for this long, the motor stops.
const unsigned long MOTOR_TIMEOUT_MS = 1200;
// ------------------------------

WebServer server(80);

bool ledOn   = false;
bool motorOn = false;
unsigned long motorLastPing = 0;

// ---------- the phone app, served from flash ----------
const char PAGE[] PROGMEM = R"rawliteral(
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="theme-color" content="#2b1d14">
<title>Teddy</title>
<style>
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html, body { height: 100%; margin: 0; }
  body {
    background: #2b1d14; color: #fff4e6;
    font-family: -apple-system, system-ui, "Segoe UI", Roboto, sans-serif;
    display: flex; flex-direction: column; align-items: center; justify-content: center;
    gap: 28px; padding: 24px 16px; user-select: none; -webkit-user-select: none;
    -webkit-touch-callout: none; touch-action: manipulation;
  }
  h1 { margin: 0; font-size: 28px; font-weight: 700; letter-spacing: .5px; }
  #status { font-size: 14px; opacity: .75; min-height: 1.2em; }
  #status.bad { color: #ff9b8a; opacity: 1; }
  #addr { display: none; gap: 8px; align-items: center; font-size: 14px; }
  #addr input { font-size: 16px; padding: 8px 10px; border-radius: 8px; border: 1px solid #7a5a3e; background: #3b2a1e; color: #fff; width: 160px; }
  .buzz {
    width: 220px; height: 220px; border-radius: 50%; border: none; cursor: pointer;
    background: radial-gradient(circle at 35% 30%, #d9985a, #a2642f 70%);
    box-shadow: 0 12px 30px rgba(0,0,0,.45), inset 0 -6px 14px rgba(0,0,0,.25);
    color: #fff; font-size: 20px; font-weight: 700; line-height: 1.3;
    touch-action: none; transition: transform .08s, box-shadow .08s, background .08s;
  }
  .buzz .big { display: block; font-size: 56px; }
  .buzz.on {
    transform: scale(.94);
    background: radial-gradient(circle at 35% 30%, #ffb46e, #d47a2a 70%);
    box-shadow: 0 4px 10px rgba(0,0,0,.45), 0 0 40px rgba(255,170,90,.6);
    animation: wobble .12s infinite;
  }
  @keyframes wobble { 0%{transform:scale(.94) rotate(-2deg)} 50%{transform:scale(.94) rotate(2deg)} 100%{transform:scale(.94) rotate(-2deg)} }
  .light {
    width: 220px; padding: 18px 0; border-radius: 999px; border: 2px solid #7a5a3e; cursor: pointer;
    background: #3b2a1e; color: #e8d5c0; font-size: 20px; font-weight: 700;
    transition: background .15s, color .15s, box-shadow .15s;
  }
  .light.on { background: #ffd978; color: #2b1d14; border-color: #ffd978; box-shadow: 0 0 36px rgba(255,217,120,.7); }
  .hint { font-size: 13px; opacity: .6; text-align: center; max-width: 260px; }
</style>
</head>
<body oncontextmenu="return false">
  <h1>🧸 Teddy</h1>
  <div id="status">connecting…</div>
  <div id="addr"><label>Bear address <input id="ip" placeholder="192.168.4.1"></label></div>

  <button class="buzz" id="buzz"><span class="big">🐾</span>hold to<br>buzz</button>
  <button class="light" id="light">💡 Light: off</button>

  <p class="hint">Press and hold the paw to make the bear vibrate. Tap the light to toggle it.</p>

<script>
  // When this page is served by the bear itself, talk to the same address.
  // When opened as a plain file on a computer, ask for the bear's IP instead.
  const servedByBear = location.protocol.startsWith('http');
  const addrBox = document.getElementById('addr');
  const ipInput = document.getElementById('ip');
  if (!servedByBear) {
    addrBox.style.display = 'flex';
    ipInput.value = localStorage.getItem('teddyIp') || '192.168.4.1';
    ipInput.addEventListener('change', () => { localStorage.setItem('teddyIp', ipInput.value.trim()); api('/state'); });
  }
  const base = () => servedByBear ? '' : 'http://' + ipInput.value.trim();

  const statusEl = document.getElementById('status');
  const buzz = document.getElementById('buzz');
  const light = document.getElementById('light');

  function render(s) {
    light.classList.toggle('on', !!s.led);
    light.textContent = '💡 Light: ' + (s.led ? 'on' : 'off');
  }
  function setStatus(ok) {
    statusEl.textContent = ok ? 'connected to bear' : "can't reach the bear";
    statusEl.classList.toggle('bad', !ok);
  }
  async function api(path) {
    try {
      const r = await fetch(base() + path, { cache: 'no-store' });
      render(await r.json());
      setStatus(true);
    } catch (e) { setStatus(false); }
  }

  // --- Hold-to-buzz ---
  // While held we re-send "on" every 400 ms; the bear switches the motor off
  // by itself if it stops hearing from us, so a dropped "off" can't leave it buzzing.
  let holdTimer = null;
  function startBuzz(e) {
    e.preventDefault();
    if (holdTimer) return;
    try { buzz.setPointerCapture(e.pointerId); } catch (_) {}
    buzz.classList.add('on');
    api('/motor/on');
    holdTimer = setInterval(() => api('/motor/on'), 400);
  }
  function stopBuzz() {
    if (!holdTimer) return;
    clearInterval(holdTimer); holdTimer = null;
    buzz.classList.remove('on');
    api('/motor/off');
  }
  buzz.addEventListener('pointerdown', startBuzz);
  buzz.addEventListener('pointerup', stopBuzz);
  buzz.addEventListener('pointercancel', stopBuzz);
  window.addEventListener('blur', stopBuzz);
  document.addEventListener('visibilitychange', () => { if (document.hidden) stopBuzz(); });

  // --- Light toggle ---
  light.addEventListener('click', () => api('/led/toggle'));

  api('/state');
</script>
</body>
</html>
)rawliteral";
// ------------------------------------------------------

void setLed(bool on) {
  ledOn = on;
  digitalWrite(LED_PIN, on ? HIGH : LOW);
}

void setMotor(bool on) {
  motorOn = on;
  digitalWrite(MOTOR_PIN, on ? HIGH : LOW);
}

void sendState() {
  String json = String("{\"led\":") + (ledOn ? "true" : "false") +
                ",\"motor\":" + (motorOn ? "true" : "false") + "}";
  server.sendHeader("Access-Control-Allow-Origin", "*");  // lets app.html work from a laptop too
  server.sendHeader("Cache-Control", "no-store");
  server.send(200, "application/json", json);
}

void handleRoot() {
  server.send_P(200, "text/html", PAGE);
}

void handleMotorOn() {
  motorLastPing = millis();
  if (!motorOn) setMotor(true);
  sendState();
}

void handleMotorOff() {
  setMotor(false);
  sendState();
}

void handleLedToggle() { setLed(!ledOn); sendState(); }
void handleLedOn()     { setLed(true);   sendState(); }
void handleLedOff()    { setLed(false);  sendState(); }
void handleState()     { sendState(); }

void handleNotFound() {
  server.send(404, "text/plain", "not found");
}

void startWifi() {
  if (strlen(HOME_SSID) > 0) {
    Serial.printf("Joining WiFi \"%s\"", HOME_SSID);
    WiFi.mode(WIFI_STA);
    WiFi.begin(HOME_SSID, HOME_PASS);
    unsigned long t0 = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t0 < 15000) {
      delay(300);
      Serial.print(".");
    }
    Serial.println();
    if (WiFi.status() == WL_CONNECTED) {
      Serial.print("Connected. Open http://");
      Serial.println(WiFi.localIP());
      if (MDNS.begin(MDNS_NAME)) {
        Serial.printf("   or http://%s.local\n", MDNS_NAME);
      }
      return;
    }
    Serial.println("Couldn't join home WiFi, falling back to hotspot mode.");
  }

  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  Serial.printf("Hotspot \"%s\" started. Join it and open http://", AP_SSID);
  Serial.println(WiFi.softAPIP());
}

void setup() {
  Serial.begin(115200);
  delay(200);

  pinMode(LED_PIN, OUTPUT);
  pinMode(MOTOR_PIN, OUTPUT);
  if (LED_NO_RESISTOR) {
    gpio_set_drive_capability((gpio_num_t)LED_PIN, GPIO_DRIVE_CAP_0);
  }
  setLed(false);
  setMotor(false);

  startWifi();

  server.on("/",            HTTP_GET, handleRoot);
  server.on("/state",       HTTP_GET, handleState);
  server.on("/motor/on",    HTTP_GET, handleMotorOn);
  server.on("/motor/off",   HTTP_GET, handleMotorOff);
  server.on("/led/toggle",  HTTP_GET, handleLedToggle);
  server.on("/led/on",      HTTP_GET, handleLedOn);
  server.on("/led/off",     HTTP_GET, handleLedOff);
  server.onNotFound(handleNotFound);
  server.begin();

  // quick "hello": blink the LED and give a short buzz so you know it booted
  setLed(true);  setMotor(true);  delay(150);
  setLed(false); setMotor(false);
}

void loop() {
  server.handleClient();

  // Safety timeout: stop the motor if the phone went quiet.
  if (motorOn && millis() - motorLastPing > MOTOR_TIMEOUT_MS) {
    setMotor(false);
  }
}
