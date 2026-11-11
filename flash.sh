#!/bin/sh
# Compile and upload a sketch to the ESP32 with arduino-cli.
#   ./flash.sh ble            # Bluetooth version (default)
#   ./flash.sh wifi           # WiFi version
#   ./flash.sh link           # linked bears: BLE setup + WiFi/MQTT (needs PubSubClient)
#   ./flash.sh ble monitor    # upload, then open the serial monitor
# Needs: brew install arduino-cli && arduino-cli core install esp32:esp32
# (On Apple Silicon also: softwareupdate --install-rosetta, for arduino's ctags.)
set -e
cd "$(dirname "$0")"
case "${1:-ble}" in
  ble)  SKETCH=teddy_bear_ble; FQBN=esp32:esp32:esp32:PartitionScheme=huge_app ;;
  wifi) SKETCH=teddy_bear;     FQBN=esp32:esp32:esp32 ;;
  link) SKETCH=teddy_link;     FQBN=esp32:esp32:esp32:PartitionScheme=huge_app ;;
  *) echo "usage: $0 [ble|wifi|link] [monitor]"; exit 1 ;;
esac
PORT=$(ls /dev/cu.usbserial* /dev/cu.usbmodem* /dev/cu.SLAB* /dev/cu.wchusbserial* 2>/dev/null | head -1)
[ -n "$PORT" ] || { echo "No ESP32 found. Plug it in (data-capable USB cable) and retry."; exit 1; }
echo "Board on $PORT"
arduino-cli compile --fqbn "$FQBN" "$SKETCH"
arduino-cli upload  --fqbn "$FQBN" -p "$PORT" "$SKETCH"
[ "$2" = "monitor" ] && arduino-cli monitor -p "$PORT" -c baudrate=115200
exit 0
