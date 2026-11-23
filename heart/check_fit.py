#!/usr/bin/env python3
"""Check that the bolt screws into each heart and the LED fits inside.

    python check_fit.py 20 25 30      (after ./build.sh has written build/<size>/)

The bolt is tried with 0, 1 and 2.5 mm of fabric between its head and the back
of the heart. In none of those may it cut into the heart, and the LED, pushed in
until its tip stops, must cut into neither.
"""
import sys

import numpy as np
import trimesh
import manifold3d as m3d


def man(m):
    return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(m.vertices, dtype=np.float32),
                                 tri_verts=np.asarray(m.faces, dtype=np.uint32)))


def gap(a, b, n=8000):
    pts = np.vstack([a.vertices, trimesh.sample.sample_surface(a, n, seed=1)[0]])
    return float(trimesh.proximity.closest_point(b, pts)[1].min())


ok = True
for w in sys.argv[1:]:
    heart = trimesh.load(f"stl/heart-{w}mm.stl", force="mesh")
    led = trimesh.load(f"build/{w}/led.stl", force="mesh")
    mh, ml = man(heart), man(led)
    size = heart.bounds[1] - heart.bounds[0]
    print(f"{w} mm heart: {size[0]:.1f} x {size[1]:.1f} x {size[2]:.1f} mm")
    for g in ("0", "1", "2.5"):
        bolt = trimesh.load(f"build/{w}/bolt-{g}.stl", force="mesh")
        mb = man(bolt)
        v, vl = (mh ^ mb).volume(), (ml ^ mb).volume()
        inside = bolt.bounds[1][2]          # how far the bolt reaches into the heart
        good = v < 1e-3 and vl < 1e-3 and inside >= 2.4
        ok &= good
        print(f"   fabric {g:>3} mm: bolt against heart {v:.4f} mm3, against LED {vl:.4f} mm3, "
              f"closest approach {gap(bolt, heart):.2f} mm, thread engaged {inside:.1f} mm  "
              f"{'PASS' if good else 'FAIL'}")
    v = (mh ^ ml).volume()
    front = heart.bounds[1][2] - led.bounds[1][2]
    good = v < 1e-3 and front >= 0.8
    ok &= good
    print(f"   LED against heart {v:.4f} mm3; {front:.2f} mm of plastic in front of its tip; "
          f"its back end is {-led.bounds[0][2]:.1f} mm behind the back of the heart  {'PASS' if good else 'FAIL'}")
sys.exit(0 if ok else 1)
