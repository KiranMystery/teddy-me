#!/usr/bin/env python3
"""Check that a 5 mm LED fits each heart and pokes out of it.

    python check_led.py 30 40 50      (after ./build.sh has written the STLs)

The LED, pushed in from the back until its flange stops, must not cut into the
heart, must have a little clearance in its hole, and its tip must stand proud
of the dome.
"""
import sys

import numpy as np
import trimesh
import manifold3d as m3d


def man(m):
    return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(m.vertices, dtype=np.float32),
                                 tri_verts=np.asarray(m.faces, dtype=np.uint32)))


ok = True
for w in sys.argv[1:]:
    heart = trimesh.load(f"stl/heart-{w}mm.stl", force="mesh")
    led = trimesh.load(f"build/led-{w}.stl", force="mesh")
    v = float((man(heart) ^ man(led)).volume())
    pts = np.vstack([led.vertices, trimesh.sample.sample_surface(led, 6000, seed=1)[0]])
    gap = float(trimesh.proximity.closest_point(heart, pts)[1].min())
    poke = led.bounds[1][2] - heart.bounds[1][2]
    behind = led.bounds[0][2] - heart.bounds[0][2]
    size = heart.bounds[1] - heart.bounds[0]
    good = v < 1e-3 and poke > 1.0 and behind >= 0.0
    ok &= good
    print(f"{w} mm: heart {size[0]:.1f} x {size[1]:.1f} x {size[2]:.1f} mm; LED intersection {v:.4f} mm3, "
          f"closest approach {gap:.2f} mm, tip {poke:.2f} mm proud of the dome, "
          f"flange {behind:.2f} mm inside the back face  {'PASS' if good else 'FAIL'}")
sys.exit(0 if ok else 1)
