#!/bin/sh
# Regenerate the paw squeeze pad STLs and renders from paw-pad.scad.
#
#   ./build.sh            STLs for 25, 30 and 40 mm plates (needs only OpenSCAD)
#   ./build.sh all        STLs + mesh check + fit check + PNG renders
#                         (needs the Python packages in ../enclosure/tools/requirements.txt)
#   SIZES="35" ./build.sh                  another plate diameter, in mm
#   SCAD_ARGS="-D sw_h=7" ./build.sh       a taller switch, or any other override
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
    "$OPENSCAD" --backend=manifold --export-format binstl "$@" ${SCAD_ARGS:-} -o "$out" paw-pad.scad 2>&1 \
        | grep -E "WARNING|ERROR" || true
}

for d in ${SIZES:-25 30 40}; do
    dir="stl/${d}mm"; mkdir -p "$dir" "build/$d"
    for p in base plate ring; do
        scad "$dir/paw-pad-$p.stl" -D "pad_d=$d" -D "part=\"$p\""
    done
    for p in base_placed ring_placed switch plate_rest plate_pressed plate_lifted plate_edge; do
        scad "build/$d/$p.stl" -D "pad_d=$d" -D "part=\"$p\""
    done
    "$OPENSCAD" -D "pad_d=$d" ${SCAD_ARGS:-} -o "build/$d/size.echo" paw-pad.scad 2>/dev/null || true
    echo "wrote $dir: $(grep -o 'PAW PAD[^"]*' "build/$d/size.echo" || true)"
done

[ "${1:-}" = "all" ] || exit 0

"$PY" ../enclosure/tools/check_mesh.py stl/*/paw-pad-*.stl | tee build/mesh-check.txt
"$PY" check_fit.py ${SIZES:-25 30 40} | tee build/fit-check.txt

mkdir -p renders
img() {  # out, camera, then -D overrides
    out=$1; cam=$2; shift 2
    "$OPENSCAD" --backend=manifold --render --imgsize=1200,950 --colorscheme=Tomorrow \
        "--camera=$cam" "$@" -o "renders/$out" paw-pad.scad >/dev/null 2>&1
    echo "rendered $out"
}
img paw-pad-assembled.png 0,0,3,58,0,30,150 -D 'part="assembly"'
img paw-pad-cutaway.png   0,0,3,72,0,0,120  -D 'part="assembly"' -D cut=true
img paw-pad-base.png      0,0,2,45,0,30,150 -D 'part="base"'
