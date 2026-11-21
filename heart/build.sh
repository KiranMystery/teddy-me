#!/bin/sh
# Regenerate the heart STLs and renders from heart.scad.
#
#   ./build.sh            STLs for 30, 40 and 50 mm windows (needs only OpenSCAD)
#   ./build.sh all        STLs + mesh check + fit check + PNG renders
#                         (needs the Python packages in ../enclosure/tools/requirements.txt)
#   SIZES="36 44" ./build.sh     other window widths, in mm
set -eu
cd "$(dirname "$0")"

OPENSCAD=${OPENSCAD:-openscad}
command -v "$OPENSCAD" >/dev/null 2>&1 || {
    echo "openscad not found. Install it with: brew install --cask openscad@snapshot" >&2; exit 1; }
PY=${PYTHON:-python3}
[ -x ../enclosure/.venv/bin/python ] && PY=../enclosure/.venv/bin/python

scad() {  # out, then -D overrides
    out=$1; shift
    "$OPENSCAD" --backend=manifold --export-format binstl "$@" -o "$out" heart.scad 2>&1 \
        | grep -E "ECHO|WARNING|ERROR" || true
}

mkdir -p build
for w in ${SIZES:-30 40 50}; do
    dir="stl/${w}mm"; mkdir -p "$dir"
    scad "$dir/heart-frame-outline.stl" -D "heart_w=$w" -D 'part="frame"' -D 'style="outline"'
    scad "$dir/heart-frame-full.stl"    -D "heart_w=$w" -D 'part="frame"' -D 'style="full"'
    scad "$dir/heart-cup.stl"           -D "heart_w=$w" -D 'part="cup"'
    scad "build/cup-placed-$w.stl"      -D "heart_w=$w" -D 'part="cup_placed"'
    echo "wrote $dir"
done

[ "${1:-}" = "all" ] || exit 0

"$PY" ../enclosure/tools/check_mesh.py stl/*/heart-*.stl | tee build/mesh-check.txt
"$PY" check_fit.py ${SIZES:-30 40 50} | tee build/fit-check.txt

mkdir -p renders
img() {  # out, camera, then -D overrides
    out=$1; cam=$2; shift 2
    "$OPENSCAD" --backend=manifold --render --imgsize=1200,950 --colorscheme=Tomorrow \
        "--camera=$cam" "$@" -o "renders/$out" heart.scad >/dev/null 2>&1
    echo "rendered $out"
}
img heart-front-outline.png 0,0,0,0,0,0,175 --projection=ortho -D 'part="frame"' -D 'style="outline"'
img heart-front-full.png    0,0,0,0,0,0,175 --projection=ortho -D 'part="frame"' -D 'style="full"'
img heart-back-assembled.png 0,0,8,62,0,25,185 -D 'part="assembly"' -D 'style="outline"'
img heart-cup-inside.png    0,0,6,50,0,20,150 -D 'part="cup"'
