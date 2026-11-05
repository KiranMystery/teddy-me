# Teddy bear – ESP32, LED and vibration motor

Phone → WiFi → ESP32 → buzz / light. No app store: the ESP32 serves the
control page itself, so any phone browser works (iOS and Android).

## Files

| File | What it is |
|---|---|
| `circuit.svg` | Wiring diagram (open in a browser) |
| `teddy_bear/teddy_bear.ino` | ESP32 sketch (Arduino IDE). The control page is embedded in it. |
| `app.html` | Same control page as a standalone file, for previewing on a laptop or using from a laptop with the bear's IP |

## Parts

| Qty | Part | Notes |
|---|---|---|
| 1 | ESP32 dev board | any common "ESP32 DevKit" / WROOM board |
| 1 | LED | any colour |
| 1 | 220 Ω resistor | LED current limit (anything 150–470 Ω is fine) |
| 1 | Coin / pancake vibration motor (3 V) | the small flat type |
| 1 | NPN transistor | 2N2222, BC337, S8050, PN2222 … or a 2N7000 MOSFET |
| 1 | 1 kΩ resistor | transistor base |
| 1 | Diode 1N4148 (or 1N4001/4007) | flyback, across the motor |
| 1 | 100 µF capacitor (optional) | across 3V3/GND, stops brownout resets when the motor starts |

## Wiring

```
                           +3.3V ───────────┬──────────┬──────── (3V3 pin)
                                            │          │
                                        ┌───┴───┐    ──┴──  D1 1N4148
   ESP32                                │ MOTOR │     ▲      (stripe/cathode
                                        └───┬───┘    ─┬─      towards 3V3)
   GPIO 26 ──[ 1kΩ ]── B                    │ C       │
                        Q1 NPN  ────────────┴─────────┘
                        E
                        │
   GPIO 25 ──[ 220Ω ]──▶|── LED ────┐       │
                                    │       │
   GND ─────────────────────────────┴───────┴────────────────────── GND
```

| ESP32 pin | goes to |
|---|---|
| GPIO 25 | 220 Ω → LED long leg (anode). LED short leg → GND |
| GPIO 26 | 1 kΩ → transistor **base** |
| 3V3 | motor **+** wire, and diode **stripe** end |
| GND | transistor **emitter**, LED short leg |
| – | motor **–** wire → transistor **collector** → diode non-stripe end |

Transistor pinout (flat face towards you, legs down) for 2N2222/BC337/S8050 is
usually **E B C** left-to-right, but check your part's datasheet. If you use a
2N7000 MOSFET: gate = base, source = emitter, drain = collector, and you can
skip R2 (or keep it, it does no harm).

**Why the transistor?** A coin motor pulls 60–100 mA plus a bigger start-up
surge. An ESP32 pin is only good for about 12 mA. Driving the motor straight
from the pin will kill that pin or the chip.

**Power in the bear:** a small USB power bank into the ESP32's USB port is the
easiest. If the ESP32 reboots when the motor kicks in, add C1 or move the
motor's + wire from 3V3 to the board's 5V/VIN pin (coin motors tolerate it for
short bursts, but it will be a lot stronger).

## No transistor or capacitor?

- **C1 is optional.** Leave it out.
- **The motor still needs a switch.** The ESP32 pin cannot supply what a coin
  motor draws, so don't wire it to GPIO 26 directly. Cheapest fixes, pick one:
  - a bare **2N2222 / BC337 / S8050 NPN** or **2N7000 MOSFET**, pennies each,
    in any electronics starter assortment (you already have the 1 kΩ for it);
  - a **logic-level MOSFET module** (search "D4184 MOSFET module"): screw
    terminals, GPIO straight to its signal pin, nothing else needed;
  - a **DRV8833 or L9110S motor driver module**: same idea, and later lets you
    set vibration strength and drive two motors.
- **No flyback diode:** for a motor this small a spare **LED** works as D1 (long
  leg to the transistor side, short leg to 3V3). It will blink each time the
  motor stops. Skip PWM/intensity control until you have a real diode.
- **Meanwhile:** wire up the LED and flash the sketch now; the whole app flow
  works without the motor. (`LED_NO_RESISTOR` in the sketch is there if you
  ever run out of 220 Ω resistors; leave it `false`.)

## Flashing

1. Arduino IDE 2.x → *File → Preferences → Additional boards manager URLs*, add
   `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
2. *Tools → Board → Boards Manager*, install **esp32 by Espressif Systems**.
3. Open `teddy_bear/teddy_bear.ino`, pick *ESP32 Dev Module* and your USB port.
4. Upload. If it hangs at "Connecting…", hold the **BOOT** button on the board
   until upload starts.
5. *Tools → Serial Monitor* at 115200 baud shows the address to open.

## Using it

**Hotspot mode (default, nothing to configure):**
the bear creates a WiFi network called `TeddyBear`, password `cuddles123`.
Join it on your phone and open **http://192.168.4.1**.
(Your phone has no internet while on that network.)

**Home WiFi mode:** set `HOME_SSID` / `HOME_PASS` at the top of the sketch.
Then open **http://teddy.local** (iPhone/Mac) or the IP from Serial Monitor
(Android often can't resolve `.local` names).

On the phone, *Share → Add to Home Screen* gives you a full-screen app icon.

- **Hold the paw** → motor runs while held, stops on release.
- **Light** → toggles the LED.

### Safety behaviour

While the paw is held the page pings the bear every 400 ms. If the bear hears
nothing for 1.2 s (phone locked, WiFi dropped, app closed) it stops the motor
by itself, so it can never get stuck buzzing.

### Simple HTTP API

Anything that can make an HTTP request can drive the bear (Shortcuts, curl…):

| URL | Does |
|---|---|
| `/state` | returns `{"led":false,"motor":false}` |
| `/motor/on` | motor on (call repeatedly while holding) |
| `/motor/off` | motor off |
| `/led/toggle`, `/led/on`, `/led/off` | LED |

## Ideas for later

- Intensity: switch `digitalWrite` on the motor to `ledcWrite` PWM and add a slider.
- Several motors/LEDs: one transistor stage per motor, one GPIO each.
- Patterns: heartbeat buzz, breathing LED, done in `loop()` with `millis()`.
- Battery: a board with a built-in LiPo charger (e.g. ESP32 "Lolin32 Lite", TTGO T-Energy).
