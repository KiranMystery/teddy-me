#!/usr/bin/env python3
"""Export every part of assembly.scad, check the fit, build the viewer.

    python tools/build_assembly.py [--board 38pin|30pin] [--power battery|usb]
                                   [--carrier full|compact|14x20] [--motor-in-box]
                                   [--check-only] [--out NAME]

--carrier compact (the perfboard cut to 14 columns) and --carrier 14x20 (the
uncut 4 x 6 cm board) always mean --power usb.

Steps
  1. openscad -D dump=true            -> the parts table (name, label, colour)
  2. openscad -D show="<part>"        -> one binary STL per part in build/
  3. checks                           -> printed and written to build/<NAME>-check.txt
       * every part is a closed manifold
       * solid parts do not intersect each other, the body or the lid
       * wires only touch the parts they are soldered or plugged into
       * a worst-case USB plug pushed into each socket clears the wall
       * the switch lever clears its slot in both positions (battery build)
       * the cable tie passes through its two slots (usb build)
       * smallest gap between each part and the printed box
  4. <NAME>.glb and <NAME>.html (self-contained three.js viewer)

Needs: openscad on PATH, and `pip install -r tools/requirements.txt`.
"""
import argparse
import base64
import concurrent.futures as cf
import json
import os
import subprocess
import sys

import numpy as np
import trimesh
import manifold3d as m3d

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SCAD = os.path.join(ROOT, "assembly.scad")

# Which parts each wire net is allowed to touch (its solder joints and plugs).
NET_ENDS = {
    "w_5v":   {"chg_term", "j_pwr", "perfboard", "c1", "r3"},
    "w_gnd":  {"chg_pcb", "chg_parts", "chg_term", "j_pwr", "j_led", "j_paw", "switch", "battery", "chg_jst",
               "led", "button", "perfboard", "c1", "q1"},
    "w_batt": {"battery", "chg_jst"},
    "w_en":   {"switch", "chg_pcb", "chg_parts"},
    "w_led":  {"j_led", "led", "perfboard", "r1"},
    "w_drv":  {"perfboard", "r2", "q1"},
    "w_motp": {"j_motor", "motor", "perfboard", "d1", "r3"},
    "w_mot":  {"j_motor", "motor", "perfboard", "d1", "q1"},
    "w_paw":  {"j_paw", "button", "perfboard"},
}
# Solid parts that are meant to be in contact / plugged into each other.
MATED = {
    frozenset(p) for p in [
        ("esp_pcb", "headers"), ("esp_pcb", "esp_shield"), ("esp_pcb", "esp_usb"), ("esp_pcb", "esp_btn"),
        ("chg_pcb", "chg_usb"), ("chg_pcb", "chg_jst"), ("chg_pcb", "chg_parts"), ("chg_pcb", "chg_term"),
        ("switch", "sw_lever"),
    ]
}


def scad_defs(args):
    d = {"board": f'"{args.board}"'}
    if args.motor_in_box:
        d["motor_in_box"] = "true"
    if args.power != "battery":
        d["power"] = f'"{args.power}"'
    if args.carrier != "full":
        d["carrier"] = f'"{args.carrier}"'
    return d


def parts_table(args, bdir):
    echo = os.path.join(bdir, "parts.echo")
    cmd = ["openscad"]
    for k, v in {**scad_defs(args), "dump": "true"}.items():
        cmd += ["-D", f"{k}={v}"]
    r = subprocess.run(cmd + ["-o", echo, SCAD], capture_output=True, text=True)
    rows = []
    text = open(echo).read() if os.path.exists(echo) else ""
    for line in text.splitlines():
        if "PART|" in line:
            body = line[line.index("PART|"):].rstrip('"')
            _, name, label, colour, group = body.split("|")
            rows.append(dict(name=name, label=label, colour=colour, group=group))
    if not rows:
        sys.exit("could not read the parts table:\n" + r.stdout + r.stderr)
    return rows


def export_part(args, name, path):
    cmd = ["openscad", "--backend=manifold", "--export-format", "binstl"]
    for k, v in {**scad_defs(args), "show": f'"{name}"'}.items():
        cmd += ["-D", f"{k}={v}"]
    cmd += ["-o", path, SCAD]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(path):
        raise RuntimeError(f"openscad failed for {name}:\n{r.stderr}")
    return name


def to_manifold(mesh):
    return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(mesh.vertices, dtype=np.float32),
                                 tri_verts=np.asarray(mesh.faces, dtype=np.uint32)))


def min_gap(a, b, n=4000):
    """Smallest distance between the surfaces of meshes a and b (sampled both ways)."""
    best = np.inf
    for src, dst in ((a, b), (b, a)):
        lo, hi = dst.bounds[0] - 3, dst.bounds[1] + 3
        pts = np.vstack([src.vertices, trimesh.sample.sample_surface(src, n * 4, seed=1)[0]])
        pts = pts[np.all((pts >= lo) & (pts <= hi), axis=1)]
        if len(pts) == 0:
            continue
        if len(pts) > n:
            pts = pts[np.random.default_rng(1).choice(len(pts), n, replace=False)]
        _, d, _ = trimesh.proximity.closest_point(dst, pts)
        best = min(best, float(d.min()))
    return best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--board", default="38pin", choices=["38pin", "30pin"])
    ap.add_argument("--power", default="battery", choices=["battery", "usb"])
    ap.add_argument("--carrier", default="full", choices=["full", "compact", "14x20"])
    ap.add_argument("--motor-in-box", action="store_true")
    ap.add_argument("--check-only", action="store_true")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()
    if args.carrier != "full":
        args.power = "usb"

    name = args.out or "assembly-14x20" if args.carrier == "14x20" else args.out or ("assembly-" + ("compact-" if args.carrier == "compact" else
                                       "usb-" if args.power == "usb" else "") + args.board
                        + ("-motor-in-box" if args.motor_in_box else ""))
    bdir = os.path.join(ROOT, "build", name)
    os.makedirs(bdir, exist_ok=True)

    parts = parts_table(args, bdir)
    print(f"[{name}] exporting {len(parts)} parts ...")
    with cf.ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as ex:
        list(ex.map(lambda p: export_part(args, p["name"], os.path.join(bdir, p["name"] + ".stl")), parts))

    meshes, mans = {}, {}
    report, problems = [], []

    def say(s=""):
        print(s)
        report.append(s)

    say(f"FIT CHECK  {name}")
    say("=" * 60)
    say("1. Manifold check (every exported part)")
    for p in parts:
        m = trimesh.load(os.path.join(bdir, p["name"] + ".stl"), force="mesh")
        meshes[p["name"]] = m
        man = to_manifold(m)
        mans[p["name"]] = man
        # wires are bundles of touching tubes: accept them on the manifold kernel's
        # verdict alone; printed and solid parts must also pass trimesh's edge check
        ok = man.status() == m3d.Error.NoError and (
            p["name"].startswith("w_") or (m.is_watertight and m.is_winding_consistent))
        if not ok:
            problems.append(f"{p['name']} is not a closed manifold")
        if p["name"] in ("body", "lid") or not ok:
            say(f"   {p['name']:11s} watertight={m.is_watertight} winding={m.is_winding_consistent} "
                f"manifold={man.status().name} tris={len(m.faces)} volume={m.volume/1000:.1f} cm3")
    say(f"   all {len(parts)} parts closed and manifold: {not problems}")

    names = [p["name"] for p in parts]
    wires = [n for n in names if n.startswith("w_")]
    plugs = [n for n in names if n.startswith("plug_")] + ["keepout"]
    box = ["body", "lid"]
    # the power cable and its tie are outside the box (the tie passes through
    # the wall): they get their own check in section 4
    outside = [n for n in names if n in ("usb_cable", "cable_tie")]
    solids = [n for n in names if n not in wires + plugs + box + outside + ["lid_screws"]]

    def vol(a, b):
        ba, bb = meshes[a].bounds, meshes[b].bounds
        if np.any(ba[0] > bb[1]) or np.any(bb[0] > ba[1]):
            return 0.0
        return float((mans[a] ^ mans[b]).volume())

    say()
    say("2. Interference (boolean intersection volume, mm3; must be 0)")
    worst = 0.0
    for i, a in enumerate(solids):
        for b in box:
            v = vol(a, b)
            worst = max(worst, v)
            if v > 1e-3:
                problems.append(f"{a} intersects {b}: {v:.3f} mm3")
        for b in solids[i + 1:]:
            if frozenset((a, b)) in MATED:
                continue
            v = vol(a, b)
            worst = max(worst, v)
            if v > 1e-3:
                problems.append(f"{a} intersects {b}: {v:.3f} mm3")
    say(f"   {len(solids)} solid parts against body, lid and each other: worst = {worst:.4f} mm3")
    v = vol("lid", "body")
    say(f"   lid against body: {v:.4f} mm3")
    if v > 1e-3:
        problems.append(f"lid intersects body: {v:.3f} mm3")
    v = max(vol("lid_screws", s) for s in solids)
    say(f"   lid screws against every solid part: worst = {v:.4f} mm3")
    if v > 1e-3:
        problems.append("a lid screw hits a part")

    # (the carrier's own corner screws are left out: they pass through the board's
    #  bare corners, outside the hole grid, into the posts)
    # (14x20: the small parts hang under the board, inside that space, on purpose)
    own = {"screws_m2"} | ({"r1", "r2", "r3", "q1", "d1", "c1"} if args.carrier == "14x20" else set())
    hits = [(s, vol("keepout", s)) for s in solids if s not in own]
    bad = [f"{s} ({v:.2f} mm3)" for s, v in hits if v > 1e-3]
    say(f"   3 mm joint-and-link space under the carrier against every solid part: "
        f"{', '.join(bad) or 'nothing intrudes'}")
    for b in bad:
        problems.append(f"{b} is in the space the carrier's solder joints need")
    if args.carrier != "full":
        # on these boards the joints come close to the supports, so the printed
        # supports under the board must stay out of that space too
        v = vol("keepout", "body")
        say(f"   the same space against the body's own supports: {v:.4f} mm3")
        if v > 1e-3:
            problems.append(f"a support under the carrier is in the space its solder joints need: {v:.3f} mm3")
    if "chg_term" in meshes:
        g = min_gap(meshes["chg_term"], meshes["perfboard"])
        say(f"   charger screw terminal to the bare underside of the carrier: {g:.2f} mm")
    else:
        g = meshes["keepout"].bounds[0][2] - meshes["body"].bounds[0][2] - 2.0
        say(f"   air between that 3 mm space and the floor: {g:.2f} mm")

    say()
    say("3. Wires (may only touch the parts they are joined to)")
    for w in wires:
        for b in box:
            v = vol(w, b)
            if v > 0.02:
                problems.append(f"wire {w} cuts into the {b}: {v:.3f} mm3")
        hits = [(s, vol(w, s)) for s in solids]
        bad = [(s, v) for s, v in hits if v > 0.02 and s not in NET_ENDS.get(w, set())]
        for s, v in bad:
            problems.append(f"wire {w} passes through {s}: {v:.3f} mm3")
        say(f"   {w:7s} box: {max(vol(w, 'body'), vol(w, 'lid')):.3f} mm3   "
            f"unexpected contacts: {', '.join(s for s, _ in bad) or 'none'}")

    say()
    say("4. Openings line up (worst-case plug body pushed fully home, lever in both positions)")
    for pl, sock in (("plug_esp", "esp_usb"), ("plug_chg", "chg_usb")):
        if pl not in meshes:
            continue
        v = vol(pl, "body") + vol(pl, "lid")
        g = min(min_gap(meshes[pl], meshes["body"]), min_gap(meshes[pl], meshes["lid"]))
        pc, sc = meshes[pl].bounds.mean(axis=0), meshes[sock].bounds.mean(axis=0)
        say(f"   {pl}: intersection with box {v:.4f} mm3, smallest gap around the plug {g:.2f} mm, "
            f"plug centre vs socket centre dy={pc[1]-sc[1]:+.2f} dz={pc[2]-sc[2]:+.2f} mm")
        if v > 1e-3 or abs(pc[1] - sc[1]) > 0.05 or abs(pc[2] - sc[2]) > 0.05:
            problems.append(f"{pl} does not line up with its cut-out")
    if "sw_lever" in meshes:
        lever = meshes["sw_lever"]
        b = lever.bounds
        travel = 2 * (b.mean(axis=0)[1] - meshes["switch"].bounds.mean(axis=0)[1])
        other = lever.copy()
        other.apply_translation([0, -travel, 0])
        for label, lv in (("on", lever), ("off", other)):
            v = float((to_manifold(lv) ^ mans["body"]).volume())
            g = min_gap(lv, meshes["body"], 1500)
            say(f"   switch lever, {label:3s} position: intersection {v:.4f} mm3, gap to slot {g:.2f} mm, "
                f"tip is {b[0][0] - meshes['body'].bounds[0][0]:.2f} mm inside the outer wall face")
            if v > 1e-3:
                problems.append("switch lever hits its slot")
    for o in outside:
        v = vol(o, "body") + vol(o, "lid")
        hit = [s for s in solids + wires + [x for x in outside if x != o] if vol(o, s) > 1e-3]
        g = min(min_gap(meshes[o], meshes["body"], 1500), min_gap(meshes[o], meshes["lid"], 1500))
        say(f"   {o}: intersection with box {v:.4f} mm3, smallest gap to the box {g:.2f} mm, "
            f"touches: {', '.join(hit) or 'nothing'}")
        if v > 1e-3 or hit:
            problems.append(f"{o} hits the box or a part")

    say()
    say("5. Smallest gap from each part to the printed box (mm; 0.0x = resting on it)")
    for s in solids:
        g = min(min_gap(meshes[s], meshes["body"]), min_gap(meshes[s], meshes["lid"]))
        say(f"   {s:10s} {g:6.2f}")
    ext = meshes["body"].bounds
    inside = [s for s in solids if s not in ("motor", "led", "button")]
    mn = np.min([meshes[s].bounds[0] for s in inside], axis=0)
    mx = np.max([meshes[s].bounds[1] for s in inside], axis=0)
    say(f"   all internal parts span x {mn[0]:.1f}..{mx[0]:.1f}, y {mn[1]:.1f}..{mx[1]:.1f}, z {mn[2]:.1f}..{mx[2]:.1f}")
    lidb = meshes["lid"].bounds
    say(f"   body outside        x {ext[0][0]:.1f}..{ext[1][0]:.1f}, y {ext[0][1]:.1f}..{ext[1][1]:.1f}, "
        f"z {ext[0][2]:.1f}..{ext[1][2]:.1f}; lid plate z {ext[1][2]:.1f}..{lidb[1][2]:.1f}, "
        f"its fins reach down to z {lidb[0][2]:.1f}")

    say()
    say("RESULT: " + ("PASS, no problems found" if not problems else f"{len(problems)} PROBLEM(S)"))
    for pr in problems:
        say("   - " + pr)
    with open(os.path.join(ROOT, "build", name + "-check.txt"), "w") as f:
        f.write("\n".join(report) + "\n")

    if args.check_only:
        return 1 if problems else 0

    # ------------------------------------------------------------ GLB
    scene = trimesh.Scene()
    for p in parts:
        if p["group"] == "check":
            continue
        m = meshes[p["name"]].copy()
        rgb = [int(p["colour"][i:i + 2], 16) for i in (1, 3, 5)]
        m.visual = trimesh.visual.TextureVisuals(material=trimesh.visual.material.PBRMaterial(
            name=p["name"], baseColorFactor=rgb + [255], metallicFactor=0.1, roughnessFactor=0.7))
        # glTF is y-up: rotate so the lid still faces up in other viewers
        m.apply_transform(trimesh.transformations.rotation_matrix(-np.pi / 2, [1, 0, 0]))
        m.apply_scale(0.001)
        scene.add_geometry(m, node_name=p["label"] or p["name"], geom_name=p["name"])
    glb = os.path.join(ROOT, name + ".glb")
    scene.export(glb)

    # ------------------------------------------------------------ HTML
    data = []
    for p in parts:
        m = meshes[p["name"]]
        idx = m.faces.astype(np.uint32)
        data.append({**p,
                     "v": base64.b64encode(np.round(m.vertices, 3).astype(np.float32).tobytes()).decode(),
                     "i": base64.b64encode(idx.tobytes()).decode()})
    with open(os.path.join(HERE, "viewer_template.html")) as f:
        html = f.read()
    with open(os.path.join(HERE, "vendor", "three-bundle.min.js")) as f:
        three = f.read()
    title = ("Teddy box, " + ("30-pin USB-C board soldered to the carrier" if args.carrier == "14x20" else
                              "30-pin DevKit V1" if args.board == "30pin" else "38-pin DevKitC")
             + (", USB powered, cut carrier" if args.carrier == "compact" else
                ", USB powered, 14 x 20 hole board" if args.carrier == "14x20" else
                ", USB powered" if args.power == "usb" else "")
             + (", motor inside" if args.motor_in_box else ""))
    html = (html.replace("/*__THREE__*/", three)
                .replace("/*__PARTS__*/null", json.dumps(data))
                .replace("__TITLE__", title))
    out = os.path.join(ROOT, name + ".html")
    with open(out, "w") as f:
        f.write(html)
    print(f"wrote {os.path.relpath(out)} ({os.path.getsize(out)/1e6:.1f} MB) and {os.path.relpath(glb)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
