#!/usr/bin/env python3
"""Render the PNG views in renders/ : the viewer through headless Chrome,
the two printable parts through OpenSCAD."""
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "renders")
CHROME = os.environ.get("CHROME") or next((c for c in (
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    shutil.which("google-chrome") or "", shutil.which("chromium") or "") if c and os.path.exists(c)), None)

VIEWS = [  # file, viewer page, hash
    ("assembly-overview.png",      "assembly-38pin.html", "view=iso"),
    ("assembly-top.png",           "assembly-38pin.html", "view=top"),
    ("assembly-under-carrier.png", "assembly-38pin.html", "view=top&carrier=hide"),
    ("assembly-lead-exits.png",    "assembly-38pin.html", "view=leads&labels=off&zoom=1.4"),
    ("assembly-battery-side.png",  "assembly-38pin.html", "view=power&labels=off&body=ghost"),
    ("assembly-underside.png",     "assembly-38pin.html", "view=below"),
    ("closed-port-side.png",       "assembly-38pin.html", "view=ports&lid=solid&labels=off&zoom=1.3"),
    ("assembly-30pin-top.png",     "assembly-30pin.html", "view=top"),
    ("usb-assembly-overview.png",  "assembly-usb-38pin.html", "view=iso"),
    ("usb-assembly-top.png",       "assembly-usb-38pin.html", "view=top"),
    ("usb-closed-port-side.png",   "assembly-usb-38pin.html", "view=ports&lid=solid&labels=off&zoom=1.3"),
    ("usb-cable-tie.png",          "assembly-usb-38pin.html", "view=iso&lid=solid&labels=off&zoom=1.2"),
    ("compact-assembly-overview.png", "assembly-compact-38pin.html", "view=iso"),
    ("compact-assembly-top.png",      "assembly-compact-38pin.html", "view=top"),
    ("compact-closed.png",            "assembly-compact-38pin.html", "view=iso&lid=solid&labels=off&zoom=1.2"),
    ("compact-30pin-top.png",         "assembly-compact-30pin.html", "view=top"),
    ("14x20-assembly-overview.png",   "assembly-14x20-38pin.html", "view=iso"),
    ("14x20-assembly-top.png",        "assembly-14x20-38pin.html", "view=top"),
    ("14x20-closed.png",              "assembly-14x20-38pin.html", "view=iso&lid=solid&labels=off&zoom=1.2"),
]
PRINT = [  # file, part, power, carrier, camera (translate xyz, rotate xyz, distance)
    ("print-body.png",     "body", "battery", "full", "40,35,16,52,0,28,265"),
    ("print-lid.png",      "lid",  "battery", "full", "40,35,8,52,0,28,265"),
    ("usb-print-body.png", "body", "usb",     "full", "40,33,12,52,0,28,250"),
    ("usb-print-lid.png",  "lid",  "usb",     "full", "40,33,8,52,0,28,250"),
    ("compact-print-body.png", "body", "usb", "compact", "34,26,12,52,0,28,215"),
    ("compact-print-lid.png",  "lid",  "usb", "compact", "34,26,8,52,0,28,215"),
    ("14x20-print-body.png", "body", "usb", "14x20", "35,28,12,52,0,28,225"),
    ("14x20-print-lid.png",  "lid",  "usb", "14x20", "35,28,8,52,0,28,225"),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    if CHROME:
        prof = tempfile.mkdtemp(prefix="teddy-chrome-")
        for name, page, frag in VIEWS:
            url = "file://" + urllib.parse.quote(os.path.join(ROOT, page)) + "#" + frag + "&ui=0&theme=light"
            subprocess.run([CHROME, "--headless=new", "--hide-scrollbars", "--force-device-scale-factor=1",
                            "--window-size=1600,1100", "--virtual-time-budget=4000",
                            f"--user-data-dir={prof}", f"--screenshot={os.path.join(OUT, name)}", url],
                           capture_output=True)
            print("rendered", name)
        shutil.rmtree(prof, ignore_errors=True)
    else:
        print("Google Chrome not found: skipping the viewer renders (set CHROME=/path/to/chrome)")
    for name, part, power, carrier, cam in PRINT:
        subprocess.run(["openscad", "--backend=manifold", "--render", "--imgsize=1600,1100",
                        f"--camera={cam}", "--colorscheme=Tomorrow", "-D", f'part="{part}"',
                        "-D", f'power="{power}"', "-D", f'carrier="{carrier}"',
                        "-o", os.path.join(OUT, name), os.path.join(ROOT, "enclosure.scad")],
                       capture_output=True)
        print("rendered", name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
