#!/bin/sh
# Regenerate the heart STLs and renders from heart.scad.
#
#   ./build.sh            STLs for 20, 30, 40 and 50 mm hearts (needs only OpenSCAD)
#   ./build.sh all        STLs + mesh check + LED fit check + PNG renders
#                         (needs the Python packages in ../enclosure/tools/requirements.txt)
#   SIZES="36 44" ./build.sh              other widths, in mm
#   SCAD_ARGS="-D dome_h=9" ./build.sh    a taller dome, or any other override
set -eu
cd "$(dirname "$0")"

OPENSCAD=${OPENSCAD:-openscad}
command -v "$OPENSCAD" >/dev/null 2>&1 || {
    echo "openscad not found. Install it with: brew install --cask openscad@snapshot" >&2; exit 1; }
PY=${PYTHON:-python3}
[ -x ../enclosure/.venv/bin/python ] && PY=../enclosure/.venv/bin/python

mkdir -p build stl
for w in ${SIZES:-20 30 40 50}; do
    # shellcheck disable=SC2086
    "$OPENSCAD" --backend=manifold --export-format binstl -D "heart_w=$w" ${SCAD_ARGS:-} \
        -o "stl/heart-${w}mm.stl" heart.scad 2>&1 | grep -E "ECHO|WARNING|ERROR" | sed 's/^ECHO: //' || true
    # shellcheck disable=SC2086
    "$OPENSCAD" --backend=manifold --export-format binstl -D "heart_w=$w" -D 'part="led"' ${SCAD_ARGS:-} \
        -o "build/led-${w}.stl" heart.scad >/dev/null 2>&1
done

[ "${1:-}" = "all" ] || exit 0

"$PY" ../enclosure/tools/check_mesh.py stl/heart-*.stl | tee build/mesh-check.txt
"$PY" check_led.py ${SIZES:-20 30 40 50} | tee build/led-check.txt

mkdir -p renders
img() {  # out, camera, then extra arguments
    out=$1; cam=$2; shift 2
    "$OPENSCAD" --backend=manifold --render --imgsize=1200,950 --colorscheme=Tomorrow \
        "--camera=$cam" "$@" -o "renders/$out" heart.scad >/dev/null 2>&1
    echo "rendered $out"
}
img heart-front.png   0,0,0,0,0,0,175 --projection=ortho -D 'part="assembly"'
img heart-angle.png   0,0,4,58,0,22,150 -D 'part="assembly"'
img heart-section.png 0,0,4,90,0,90,120 --projection=ortho -D 'part="assembly"' -D cut=true
img heart-back.png    0,0,2,180,0,0,175 --projection=ortho -D 'part="heart"'
img heart-20mm.png    0,0,3,58,0,22,110 -D 'part="assembly"' -D heart_w=20
