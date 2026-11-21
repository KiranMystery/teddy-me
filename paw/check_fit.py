#!/usr/bin/env python3
"""Check that the paw pad goes together and moves, for each plate diameter.

    python check_fit.py 25 30 40      (after ./build.sh has written build/<d>/)

The plate is tried in four positions: resting on the plunger, pressed in the
middle, lifted against the ring, and tipped by a press on its edge. In none of
them may it cut into the base, the ring or the switch body.
"""
import sys

import numpy as np
import trimesh
import manifold3d as m3d


def load(d, name):
    return trimesh.load(f"build/{d}/{name}.stl", force="mesh")


def man(m):
    return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(m.vertices, dtype=np.float32),
                                 tri_verts=np.asarray(m.faces, dtype=np.uint32)))


def gap(a, b, n=6000):
    best = np.inf
    for s, t in ((a, b), (b, a)):
        pts = np.vstack([s.vertices, trimesh.sample.sample_surface(s, n, seed=1)[0]])
        best = min(best, float(trimesh.proximity.closest_point(t, pts)[1].min()))
    return best


ok = True
for d in sys.argv[1:]:
    base, ring, sw = load(d, "base_placed"), load(d, "ring_placed"), load(d, "switch")
    mb, mr, ms = man(base), man(ring), man(sw)
    print(f"{d} mm plate")
    v = (mb ^ mr).volume()
    g = gap(base, ring)
    print(f"   ring on base: intersection {v:.4f} mm3, gap {g:.2f} mm")
    ok &= v < 1e-3
    v = (mb ^ ms).volume()
    print(f"   switch in its pocket: intersection {v:.4f} mm3, gap to the ribs {gap(sw, base):.2f} mm "
          f"(0.00 = the legs lie on the floor)")
    ok &= v < 1e-3
    for pose in ("plate_rest", "plate_pressed", "plate_lifted", "plate_edge"):
        p = load(d, pose)
        mp = man(p)
        vb, vr = (mp ^ mb).volume(), (mp ^ mr).volume()
        # against the switch BODY only: the plunger is what the plate pushes down
        body = trimesh.creation.box(extents=[6.0, 6.0, 3.5])
        body.apply_translation([0, 0, 1.75])
        vs = (mp ^ man(body)).volume()
        good = vb < 1e-3 and vr < 1e-3 and vs < 1e-3
        ok &= good
        print(f"   {pose:14s} against base {vb:.4f}, ring {vr:.4f}, switch body {vs:.4f} mm3; "
              f"gap to base {gap(p, base):.2f}, to ring {gap(p, ring):.2f} mm  {'PASS' if good else 'FAIL'}")
    top = load(d, "plate_rest").bounds[1][2]
    print(f"   plate stands {top - ring.bounds[1][2]:.2f} mm above the ring; pod is "
          f"{top - base.bounds[0][2]:.1f} mm tall, {ring.bounds[1][0] - ring.bounds[0][0]:.1f} mm across")
sys.exit(0 if ok else 1)
