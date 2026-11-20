#!/usr/bin/env python3
"""Check that the printable STLs are closed, manifold, single-piece solids.

    python tools/check_mesh.py stl/38pin/teddy-box-body.stl stl/38pin/teddy-box-lid.stl

Exit code 1 if any file fails. Needs `pip install -r tools/requirements.txt`.
"""
import sys

import numpy as np
import trimesh
import manifold3d as m3d


def check(path):
    m = trimesh.load(path, force="mesh")
    man = m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(m.vertices, dtype=np.float32),
                                tri_verts=np.asarray(m.faces, dtype=np.uint32)))
    # every edge must be shared by exactly two triangles
    edges = np.sort(m.edges, axis=1)
    _, counts = np.unique(edges, axis=0, return_counts=True)
    open_edges = int((counts == 1).sum())
    bad_edges = int((counts > 2).sum())
    bodies = len(m.split(only_watertight=False))
    size = m.bounds[1] - m.bounds[0]
    ok = (m.is_watertight and m.is_winding_consistent and m.is_volume and open_edges == 0
          and bad_edges == 0 and bodies == 1 and man.status() == m3d.Error.NoError
          and abs(m.bounds[0][2]) < 1e-3)
    print(f"{path}\n"
          f"   {'PASS' if ok else 'FAIL'}  watertight={m.is_watertight}  winding consistent={m.is_winding_consistent}  "
          f"open edges={open_edges}  non-manifold edges={bad_edges}  separate bodies={bodies}\n"
          f"   manifold kernel: {man.status().name}  genus={man.genus()}  euler={m.euler_number}  "
          f"triangles={len(m.faces)}\n"
          f"   size {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f} mm, sits on z={m.bounds[0][2]:.3f}, "
          f"volume {m.volume/1000:.1f} cm3 (about {m.volume/1000*1.25:.0f} g solid PETG)")
    return ok


if __name__ == "__main__":
    results = [check(p) for p in sys.argv[1:]]
    sys.exit(0 if results and all(results) else 1)
