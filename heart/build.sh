#!/bin/sh
# Regenerate the heart STLs and renders from heart.scad.
#
#   ./build.sh            hearts 20, 25 and 30 mm wide, and the one bolt that
#                         fits them all (needs only OpenSCAD)
#   ./build.sh all        STLs + mesh check + fit check + PNG renders
#                         (needs the Python packages in ../enclosure/tools/requirements.txt)
#   SIZES="22 36" ./build.sh                 other widths, in mm
#   SCAD_ARGS="-D th_clear=0.45" ./build.sh  a looser thread, or any other override
set -eu
cd "$(dirname "$0")"

OPENSCAD=${OPENSCAD:-openscad}
command -v "$OPENSCAD" >/dev/null 2>&1 || {
    echo "openscad not found. Install it with: brew install --cask openscad@snapshot" >&2; exit 1; }
PY=${PYTHON:-python3}
[ -x ../enclosure/.venv/bin/python ] && PY=../enclosure/.venv/bin/python

scad() {  # out, then -D overrides
    out=$1; shift
    # shellcheck disable=SC2086
    "$OPENSCAD" --backend=manifold --export-format binstl "$@" ${SCAD_ARGS:-} -o "$out" heart.scad 2>&1 \
        | grep -E "ECHO|WARNING|ERROR" | sed 's/^ECHO: //' || true
}

mkdir -p build stl
scad stl/heart-bolt.stl -D 'part="bolt"' >/dev/null
for w in ${SIZES:-20 25 30}; do
    mkdir -p "build/$w"
    scad "stl/heart-${w}mm.stl" -D "heart_w=$w"
    scad "build/$w/led.stl" -D "heart_w=$w" -D 'part="led"' >/dev/null
    for g in 0 1 2.5; do
        scad "build/$w/bolt-$g.stl" -D "heart_w=$w" -D 'part="bolt_placed"' -D "gap=$g" >/dev/null
    done
done

[ "${1:-}" = "all" ] || exit 0

"$PY" ../enclosure/tools/check_mesh.py stl/heart-*.stl | tee build/mesh-check.txt
"$PY" check_fit.py ${SIZES:-20 25 30} | tee build/fit-check.txt

mkdir -p renders
img() {  # out, camera, then extra arguments
    out=$1; cam=$2; shift 2
    "$OPENSCAD" --backend=manifold --render --imgsize=1200,950 --colorscheme=Tomorrow \
        "--camera=$cam" "$@" -o "renders/$out" heart.scad >/dev/null 2>&1
    echo "rendered $out"
}
img heart-front.png   0,0,3,40,0,20,75 -D 'part="heart"'
img heart-parts.png   0,0,-3,115,0,25,95 -D 'part="assembly"' -D gap=6
img heart-section.png 0,0,0,90,0,90,60 --projection=ortho -D 'part="assembly"' -D cut=true -D gap=1
img heart-back.png    0,0,0,150,0,20,80 -D 'part="assembly"' -D gap=1
img heart-bolt.png    0,0,3,60,0,25,60 -D 'part="bolt"'
