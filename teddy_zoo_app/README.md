# Teddy zoo – the Flutter app

Native iOS and Android version of [`zoo.html`](../zoo.html): the same screens,
copy and behaviour, reimplemented in Flutter so the phone can do the Bluetooth
setup that an iPhone home-screen web app cannot. The web app stays the
reference; when the two disagree, `zoo.html` wins.

| Screen | What it does |
|---|---|
| **Zoo** | Every animal on your zoo code with filter chips (All / Mine / Linked to mine / Online / one per other owner), online dots, "Add an animal" |
| **Animal** | Hold-to-buzz paw (sends `motor:1` every 400 ms while held, `motor:0` on release, cancel or when the app goes to the background), Light Off / Pulse / Steady (`led` 0 / 1 / 2), paw-trigger list, edit sheet, "It's mine", "Send back to Bluetooth setup" |
| **Paw triggers** | Tick the animals this paw reaches; Save publishes the retained `links/<id>` |
| **Settings** | Your name, theme (Auto / Light / Dark), zoo code as a QR with a share sheet, switch zoo, broker, leave zoo |
| **Join** | Landing for `https://iome.uk/zoo/<code>` (and `teddyzoo://zoo/<code>`, `…?join=<code>`): previews the zoo, one tap joins |
| **Add an animal** | Four steps over Bluetooth LE: find → WiFi picker (the animal scans; bars, lock, Other, show/hide password, zoo code with New) → joining (waits for `state/<id>` online; 15 s "Continue without waiting", 30 s help + "Connect again over Bluetooth") → name / species / owner. The WiFi failure reason from `INFO` (`wifi=fail:<n>`) is shown on the found card, in the status line and under the password |

Protocol details (BLE UUIDs, MQTT topics, payloads) are in the
[main README](../README.md#mqtt-topics-pair-is-the-pair-code-id-the-6-hex-bear-id).

## Layout

```
lib/
  main.dart                 app, theme switching, go_router routes + deep-link redirects
  theme.dart                brand tokens (ported from brand/tokens.css) → ThemeData light/dark, Jost + Work Sans
  model/animal.dart         Animal, labels, zoo-code validation, share URL
  model/zoo_model.dart      ZooModel: settings (shared_preferences), MQTT client, animals, join preview
  services/ble_setup.dart   AddController: the 4-step Bluetooth setup state machine (flutter_blue_plus)
  screens/                  zoo, animal, links, settings, join, add_animal
  widgets/ui.dart           cards, buttons, pills, chips, dots, heart, segmented control, rows, sheets
assets/brand/               wordmark.svg, heart.svg, icon.svg (copied from ../brand/), icon-1024.png (rendered from icon.svg)
```

Stored on the phone (`shared_preferences`, same keys as the web app's
localStorage): `teddy.pair` (zoo code), `teddy.owner`, `teddy.broker`,
`teddy-theme`, `teddy.ssid` (last WiFi picked), `teddy.myBear`.

## Build and run

Prerequisites: Flutter 3.50+ (stable), Xcode 16+ with an iOS simulator,
Android SDK with an emulator (the project targets the Flutter defaults:
minSdk 24, iOS 15).

```bash
cd teddy_zoo_app
flutter pub get
flutter run                      # picks the connected device / running simulator
flutter run -d <device id>       # flutter devices lists them
flutter analyze && flutter test
```

Bluetooth does not exist in the iOS simulator or the Android emulator, so
"Add an animal" needs a real phone. Everything over MQTT works in a simulator.
To try the zoo without hardware, put a fake animal on a test code with any
MQTT client, for example with `mosquitto_pub -h broker.emqx.io -t teddy/<code>/state/abc123 -r -m '{"id":"abc123","online":1,"led":0}'`,
then Settings → Switch to another zoo → `<code>`.

### Permissions already in the project

- iOS `Info.plist`: `NSBluetoothAlwaysUsageDescription`,
  `NSBluetoothPeripheralUsageDescription`, `FlutterDeepLinkingEnabled`,
  the `teddyzoo` URL scheme, portrait only, `ITSAppUsesNonExemptEncryption = NO`.
- iOS `Runner.entitlements`: Associated Domains `applinks:iome.uk`
  (universal links). Xcode needs a team that has the Associated Domains
  capability for this to be signed; for a local build on your own phone you
  can remove the entitlement temporarily.
- Android `AndroidManifest.xml`: `INTERNET`, `BLUETOOTH_SCAN`
  (`neverForLocation`), `BLUETOOTH_CONNECT`, and for Android 11 and older
  `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_FINE_LOCATION`,
  `ACCESS_COARSE_LOCATION` (`maxSdkVersion 30`). flutter_blue_plus asks for the
  runtime permissions when the scan starts. Intent filters for
  `https://iome.uk/zoo/*` (verified App Link) and `teddyzoo://`.

### Deep links need two files on iome.uk

For the QR / share link to open the app instead of the browser:

- `https://iome.uk/.well-known/apple-app-site-association` (no extension,
  `Content-Type: application/json`):
  ```json
  { "applinks": { "details": [ { "appIDs": ["<TEAMID>.uk.iome.teddyzoo"], "components": [ { "/": "/zoo/*" } ] } ] } }
  ```
- `https://iome.uk/.well-known/assetlinks.json`:
  ```json
  [{ "relation": ["delegate_permission/common.handle_all_urls"],
     "target": { "namespace": "android_app", "package_name": "uk.iome.teddyzoo",
                 "sha256_cert_fingerprints": ["<SHA-256 of the release signing key>"] } }]
  ```
  (`keytool -list -v -keystore <keystore>` prints the fingerprint; add the
  Play App Signing certificate too.)

Without them the link still opens the web app (`zoo.html?join=<code>` via the
host rewrite rule in the main README), which is the intended fallback.

## Store builds

Ids: bundle id / application id `uk.iome.teddyzoo`, display name "Teddy zoo".
Icons are generated from `assets/brand/icon-1024.png` with
`dart run flutter_launcher_icons` (re-run after replacing the icon).
Versions come from `pubspec.yaml` (`version: 1.0.0+1` → 1.0.0 build 1).

**iOS (App Store / TestFlight)**

1. `open ios/Runner.xcworkspace`, select the Runner target → Signing &
   Capabilities, pick your team (bundle id `uk.iome.teddyzoo`). Keep the
   Associated Domains capability.
2. `flutter build ipa --release` produces `build/ios/ipa/*.ipa` and an
   `.xcarchive`; upload with Transporter or `xcrun altool`, or Product →
   Archive in Xcode.
3. App Store Connect: Bluetooth is declared by the usage strings above;
   there is no tracking, no account, no purchases.

**Android (Play)**

1. Create a release keystore and `android/key.properties`, and wire it into
   `android/app/build.gradle.kts` as in the Flutter docs
   (<https://docs.flutter.dev/deployment/android#signing-the-app>).
2. `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.
3. Play Console: Bluetooth permissions need no declaration form;
   `ACCESS_FINE_LOCATION` is capped at API 30 so the location declaration
   does not apply to current devices.

## Packages

flutter_blue_plus (BLE), mqtt_client (wss to the broker), qr_flutter,
share_plus, flutter_svg, shared_preferences, google_fonts (Jost, Work Sans,
fetched on first run and cached), go_router (routes and deep links), provider,
url_launcher, material_ui (Flutter 3.50 moved Material here).

flutter_blue_plus 2.x is free for personal, educational and nonprofit use
(`License.nonprofit` is passed on connect). Selling the app or shipping it
from a for-profit company needs their commercial licence, or pin
`flutter_blue_plus: ^1.35.0` (BSD) and drop the `license:` argument.

## Not covered yet

- Tested on the iOS simulator and the Android emulator against the public
  broker with a fake animal; the Bluetooth add flow is written to the firmware
  contract but has not been run against a real ESP32 from this app.
- Universal / App Links need the two well-known files on iome.uk (above).
- No background MQTT: the app disconnects when suspended and reconnects on
  resume; the animal stops the motor by itself 1.2 s after the last `motor:1`.
