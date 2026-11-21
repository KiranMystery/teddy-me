#!/usr/bin/env python3
"""Check that the cup fits the frame, for each window width given.

    python check_fit.py 30 40 50      (after ./build.sh has written the STLs)

For both frame styles: the cup, pushed home, must not intersect the frame, and
the gap between them must be there: 0.2 mm at the wall, 0.1 mm at the rim
(room for the film).
"""
import sys

import numpy as np
import trimesh
import manifold3d as m3d


def man(m):
    return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(m.vertices, dtype=np.float32),
                                 tri_verts=np.asarray(m.faces, dtype=np.uint32)))


def gap(a, b, n=6000):
    pts = np.vstack([a.vertices, trimesh.sample.sample_surface(a, n, seed=1)[0]])
    return float(trimesh.proximity.closest_point(b, pts)[1].min())


ok = True
for w in sys.argv[1:]:
    cup = trimesh.load(f"build/cup-placed-{w}.stl", force="mesh")
    for style in ("outline", "full"):
        frame = trimesh.load(f"stl/{w}mm/heart-frame-{style}.stl", force="mesh")
        v = float((man(cup) ^ man(frame)).volume())
        g = min(gap(cup, frame), gap(frame, cup))
        size = frame.bounds[1] - frame.bounds[0]
        back = cup.bounds[1][2]
        good = v < 1e-3 and 0.05 <= g <= 0.25
        ok &= good
        print(f"{w} mm, {style:7s}: frame {size[0]:.1f} x {size[1]:.1f} x {size[2]:.1f} mm, "
              f"cup/frame intersection {v:.4f} mm3, smallest gap {g:.2f} mm, "
              f"assembled depth {back:.1f} mm  {'PASS' if good else 'FAIL'}")
sys.exit(0 if ok else 1)
