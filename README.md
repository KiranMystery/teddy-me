# Teddy bear – ESP32, LED and vibration motor

Phone → ESP32 → buzz / light. Two flavours, same buttons:

- **Bluetooth (BLE)** – `teddy_bear_ble/` + `app-ble.html`. Phone keeps its
  normal WiFi/internet. Needs a browser with Web Bluetooth (see below).
- **WiFi** – `teddy_bear/` + `app.html`. The ESP32 serves the page itself, so
  it works in *any* browser, but the phone has to join the bear's hotspot.

## Files

| File | What it is |
|---|---|
| `circuit.svg` | Full wiring diagram, LED + motor (open in a browser) |
| `circuit-led.svg` | LED only, for getting started before the transistor arrives |
| `teddy_bear_ble/teddy_bear_ble.ino` | **Bluetooth** ESP32 sketch |
| `app-ble.html` | **Bluetooth** control page (Web Bluetooth) |
| `teddy_bear/teddy_bear.ino` | **WiFi** ESP32 sketch, control page embedded in it |
| `app.html` | WiFi control page as a standalone file |

## Parts

| Qty | Part | Notes |
|---|---|---|
| 1 | ESP32 dev board | any common "ESP32 DevKit" / WROOM board, 30-pin or 38-pin (see "Which pin is which?") |
| 1 | LED | any colour |
| 1 | 220 Ω resistor | LED current limit (anything 150–470 Ω is fine) |
| 1 | Coin / pancake vibration motor (3 V) | the small flat type |
| 1 | NPN transistor | 2N2222, BC337, S8050, PN2222 … or a 2N7000 MOSFET |
| 1 | 1 kΩ resistor | transistor base |
| 1 | Diode 1N4148 (or 1N4001/4007) | flyback, across the motor |
| 1 | 10–100 µF capacitor (optional) | across 3V3/GND, stops brownout resets when the motor starts. Bigger is better; 10 µF is fine to start. If electrolytic, + leg to 3V3 |

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

### Which pin is which?

Pin labels only help if they match your board. The 30-pin "DevKit V1" and the
38-pin "DevKitC" have different layouts, and a screw-terminal adapter printed
for one is wrong for the other (this is what held up the motor on the bench:
a 38-pin board in a 30-pin adapter). The reliable method: get the LED working
on GPIO 25 first, then count from that pin. Hold the board USB socket down,
antenna up; GPIO 25 is the **9th pin from the antenna end** on both boards,
and in that same column:

| 30-pin DevKit V1 (15 per side) | 38-pin DevKitC (19 per side) |
|---|---|
| 1 = **3V3** | 1 = **3V3** |
| 9 = **GPIO 25** | 9 = **GPIO 25** |
| 10 = **GPIO 26** | 10 = **GPIO 26** |
| 14 = **GND** | 14 = **GND** |
| 5V is **VIN**, top of the *other* column | 19 = **5V** (bottom, by the USB socket) |

On the 38-pin board never use pins 16–18 of that column (D2, D3, CMD) or the
last three of the other column (D1, D0, CLK): they're the flash chip.

Without a meter, your LED is a probe: short leg on GND, touch the resistor end
to a pin. Steady light = 3V3 or 5V (5V is brighter), dark = GPIO or GND. Don't
probe EN, it resets the board.

## Wiring the motor, step by step

Unplug the USB first. Everything below is the right-hand half of `circuit.svg`.

1. **Pick a transistor** from the kit. Any of these NPN types: **2N2222 / PN2222,
   S8050, BC337** (best, 500 mA+), or **2N3904 / BC547** (fine for one coin
   motor, don't add a second). A **2N7000** MOSFET also works: gate = base,
   drain = collector, source = emitter, no base resistor needed.
2. **Find its legs.** Flat face towards you, legs pointing down, left to right:

   | Part | Legs |
   |---|---|
   | 2N2222 / PN2222 / 2N3904 / S8050 | E  B  C |
   | BC337 / BC547 | C  B  E |
   | 2N7000 | S  G  D |

   If you get C and E swapped nothing breaks, the motor just barely twitches:
   turn the transistor round.
3. **Base:** 1 kΩ resistor from the **26** terminal to the transistor's **B** leg.
4. **Emitter:** **E** leg straight to **GND**.
5. **Motor:** red wire to **3V3**, the other wire (blue/black) to the **C** leg.
   Direction doesn't matter for a vibration motor. The motor's wires are hair
   thin, so twist each onto a jumper wire, or clamp them in the screw terminals.
6. **Flyback diode** across the motor: the **striped** end to the 3V3 side,
   plain end to the C-leg side. Any 1N4148 / 1N4001-4007. No diode in the kit?
   A spare **LED** does the job: long leg to the C side, short leg to 3V3.
7. **Capacitor** (100 µF or whatever is biggest in the kit, 10 µF at a pinch)
   between **3V3** and **GND**, as near the ESP32 as you can. Electrolytics
   have a polarity: long leg to 3V3, the leg beside the stripe to GND.
8. Plug the USB back in. The boot "hello" gives one short buzz and blink.
   Then connect from the page and hold the paw.

If the motor does nothing: pull its wire off the C leg and touch it straight
to GND. Spins → the transistor side is wrong (PNP by mistake? C/E swapped?
10 kΩ instead of 1 kΩ?). Doesn't spin → either the hair-thin motor leads
aren't making contact (scrape the enamel off and twist them onto solid jumper
wire), or you're not on the pin you think (see "Which pin is which?" above).
The serial monitor settles the software side: every press should print
`motor ON (GPIO 26)` and release `motor off (GPIO 26)`.

If the ESP32 reboots when the motor kicks in (you'll see it disconnect from the
page, and the serial log says "Brownout detector was triggered"), the capacitor
isn't enough: use a bigger one, or move the motor's red wire from 3V3 to the
board's **VIN / 5V** pin.

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

## Flashing (either sketch)

**From the terminal** (what `flash.sh` does): install arduino-cli, the esp32 core,
and on Apple Silicon also Rosetta (arduino-cli's ctags helper is Intel-only).
Then `./flash.sh ble` or `./flash.sh wifi`, add `monitor` to watch the serial output.

**From the Arduino IDE:**

1. Arduino IDE 2.x → *File → Preferences → Additional boards manager URLs*, add
   `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
2. *Tools → Board → Boards Manager*, install **esp32 by Espressif Systems**.
3. Open `teddy_bear/teddy_bear.ino`, pick *ESP32 Dev Module* and your USB port.
4. Upload. If it hangs at "Connecting…", hold the **BOOT** button on the board
   until upload starts.
5. *Tools → Serial Monitor* at 115200 baud shows what it's doing.
6. BLE sketch only: if the upload says the sketch is too big, set
   *Tools → Partition Scheme → Huge APP*.

## Using it – Bluetooth

1. Flash `teddy_bear_ble/teddy_bear_ble.ino`. The bear advertises as **Teddy**.
2. Open `app-ble.html` in a browser that supports Web Bluetooth, **from an
   https page or localhost** (browsers refuse Bluetooth on plain file/http pages):
   - **Android:** Chrome.
   - **Mac / Windows laptop:** Chrome or Edge. Quickest way to try it: in this
     folder run `python3 -m http.server 8000` and open http://localhost:8000/app-ble.html
   - **iPhone:** Safari has no Web Bluetooth. Install the free **Bluefy** app
     (a browser with Bluetooth) and open the page in that.
   - To use it on the phone the page needs hosting somewhere with https
     (GitHub Pages, Netlify…). Nothing in it is secret, so a public host is fine.
3. Tap **Connect to bear**, pick *Teddy* in the list. Then hold the paw / tap the light.

No pairing needed; the bear accepts one phone at a time and stops the motor the
moment the connection drops.

### BLE service (for building your own app later)

| UUID | Characteristic | Does |
|---|---|---|
| `0e7a1000-7edd-4bea-a000-5eed12345678` | service | |
| `0e7a1001-…` | motor | write 1 = buzz, 0 = stop. Keep writing 1 every ≤1 s while holding |
| `0e7a1002-…` | led | write 1/0, read, notify on change |

## Using it – WiFi

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

### Safety behaviour (both versions)

While the paw is held the page pings the bear every 400 ms. If the bear hears
nothing for 1.2 s (phone locked, connection dropped, app closed) it stops the
motor by itself, so it can never get stuck buzzing.

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
- A proper phone app: the BLE service table above is all a Swift (CoreBluetooth)
  or Flutter (flutter_blue_plus) app needs.
- Battery: a board with a built-in LiPo charger (e.g. ESP32 "Lolin32 Lite", TTGO T-Energy).
