#!/bin/sh
# Regenerate everything in this folder from the OpenSCAD sources.
#
#   ./build.sh            printable STLs for both boards, battery and USB-powered
#                         (needs only OpenSCAD)
#   ./build.sh all        STLs + mesh check + fit check + viewer + PNG renders
#                         (needs the Python packages in tools/requirements.txt,
#                          PNG renders also need Google Chrome)
#
# Extra OpenSCAD overrides can be passed in SCAD_ARGS, for example
#   SCAD_ARGS="-D motor_in_box=true -D wire_d=1.2" ./build.sh
set -eu
cd "$(dirname "$0")"

OPENSCAD=${OPENSCAD:-openscad}
command -v "$OPENSCAD" >/dev/null 2>&1 || {
    echo "openscad not found. Install it with: brew install --cask openscad@snapshot" >&2; exit 1; }
PY=${PYTHON:-python3}
[ -x .venv/bin/python ] && PY=.venv/bin/python

# stl/38pin, stl/30pin: battery build.  stl/usb-38pin, stl/usb-30pin: no
# battery, powered through the ESP32's own USB socket.
for power in battery usb; do
for board in 38pin 30pin; do
    dir="stl/$board"; [ "$power" = usb ] && dir="stl/usb-$board"
    mkdir -p "$dir"
    for p in body lid; do
        out="$dir/teddy-box-$p.stl"
        # shellcheck disable=SC2086
        "$OPENSCAD" --backend=manifold --export-format binstl \
            -D "board=\"$board\"" -D "power=\"$power\"" -D "part=\"$p\"" ${SCAD_ARGS:-} \
            -o "$out" enclosure.scad 2>&1 | grep -E "ECHO|WARNING|ERROR" || true
        echo "wrote $out"
    done
done
done

[ "${1:-}" = "all" ] || exit 0

mkdir -p build
"$PY" tools/check_mesh.py stl/*/teddy-box-*.stl | tee build/mesh-check.txt

"$PY" tools/build_assembly.py --board 38pin
"$PY" tools/build_assembly.py --board 30pin
"$PY" tools/build_assembly.py --board 38pin --motor-in-box --check-only
"$PY" tools/build_assembly.py --board 30pin --motor-in-box --check-only
"$PY" tools/build_assembly.py --board 38pin --power usb
"$PY" tools/build_assembly.py --board 30pin --power usb
"$PY" tools/build_assembly.py --board 38pin --power usb --motor-in-box --check-only
"$PY" tools/build_assembly.py --board 30pin --power usb --motor-in-box --check-only
"$PY" tools/render_views.py
