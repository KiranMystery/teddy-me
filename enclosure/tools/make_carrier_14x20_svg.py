"""Carrier for a 30-pin USB-C ESP32 soldered straight onto an uncut 4 x 6 cm
perfboard with 14 x 20 holes. ESP32 and connectors on top, everything else
underneath. Draws the BOTTOM view. Usage: make_carrier_14x20_svg.py out.svg
Checks the drawn connections against the intended netlist before writing."""
import sys
outp = sys.argv[1]
names = ['EN','VP','VN','D34','D35','D32','D33','D25','D26','D27','D14','D12','D13','GND','VIN']   # antenna end first
n = len(names)
COLS, ROWS, HC, HC2, R0 = 14, 20, 4, 14, 3      # ESP32 pin columns 4 (K) and 14 (A); EN in row 3, VIN in row 17
row = {nm: i + R0 for i, nm in enumerate(names)}
g, RG, RP = row['D25'], row['GND'], row['VIN']
def L(c): return chr(ord('A') + COLS - c)        # the board's own column letters: column 14 is A, column 1 is N
def hole(xy): return '%s%d' % (L(xy[0]), ROWS + 1 - xy[1])   # e.g. K4 = column K, 4th row from the USB end

P = {
 'ESP':  {'D25': (HC, g), 'D26': (HC, g+1), 'D27': (HC, g+2), 'GND': (HC, RG), 'VIN': (HC, RP)},
 'R1':   {'a': (5, g), 'b': (8, g)},
 'R2':   {'a': (5, g+1), 'b': (8, g+1)},
 'Q1':   {'C': (10, g), 'B': (10, g+1), 'E': (10, g+2)},
 'D1':   {'a': (10, g-1), 'k': (13, g-1)},
 'R3':   {'a': (10, RP), 'b': (13, RP)},
 'C1':   {'+': (5, RP), '-': (5, RP-1)},
 'JMOT': {'+': (1, g-3), '-': (1, g-2)},
 'JPAW': {'a': (1, g+2), 'b': (1, g+3)},
 'JLED': {'-': (1, g+6), '+': (1, g+7)},
}
def run(c1, r1, c2, r2):
    assert c1 == c2 or r1 == r2
    if c1 == c2: return [(c1, r) for r in range(min(r1, r2), max(r1, r2) + 1)]
    return [(c, r1) for c in range(min(c1, c2), max(c1, c2) + 1)]
GB = max(RG, g+6)
BARE = [
 ('#111', [run(2, RG, 10, RG), run(10, g+2, 10, RG), run(2, g+3, 2, GB), run(1, g+3, 2, g+3), run(1, g+6, 2, g+6)]),
 ('#b91c1c', [run(HC, RP, 10, RP)]),
 ('#16a34a', [run(HC, g, 5, g)]),
 ('#ca8a04', [run(HC, g+1, 5, g+1)]), ('#ca8a04', [run(8, g+1, 10, g+1)]),
 ('#7c3aed', [run(10, g-1, 10, g)]),
 ('#ea580c', [run(13, g-1, 13, RP)]),
 ('#2563eb', [run(1, g+2, HC, g+2)]),
]
WIRES = [
 ('#16a34a', (8, g), (1, g+7), 'LED +'),
 ('#ea580c', (13, g-1), (1, g-3), 'motor +'),
 ('#7c3aed', (10, g-1), (1, g-2), 'motor -'),
]
# ---- verify ----
parent = {}
def find(x):
    parent.setdefault(x, x)
    while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
    return x
def union(a, b): parent[find(a)] = find(b)
pins = {}
for part, pp in P.items():
    for pin, xy in pp.items():
        assert 1 <= xy[0] <= COLS and 1 <= xy[1] <= ROWS, (part, pin, xy)
        assert xy not in pins, ('two legs in one hole', xy, part, pins.get(xy))
        pins[xy] = f'{part}.{pin}'
esp_holes = {(c, r) for c in (HC, HC2) for r in range(R0, R0 + n)}
used = set(P['ESP'].values())
for col, runs in BARE:
    for rn in runs:
        for a, b in zip(rn, rn[1:]): union(a, b)
        for xy in rn:
            assert 1 <= xy[0] <= COLS and 1 <= xy[1] <= ROWS, xy
            assert xy not in esp_holes or xy in used, ('bare run touches an unused ESP32 pin', xy)
for _, a, b, _ in WIRES: union(a, b)
nets = {}
for xy, nm in pins.items(): nets.setdefault(find(xy), set()).add(nm)
got = sorted(sorted(v) for v in nets.values())
want = sorted(sorted(v) for v in [
 {'ESP.VIN', 'C1.+', 'R3.a'},
 {'ESP.GND', 'C1.-', 'Q1.E', 'JLED.-', 'JPAW.b'},
 {'ESP.D25', 'R1.a'}, {'R1.b', 'JLED.+'},
 {'ESP.D26', 'R2.a'}, {'R2.b', 'Q1.B'},
 {'Q1.C', 'JMOT.-', 'D1.a'},
 {'R3.b', 'JMOT.+', 'D1.k'},
 {'ESP.D27', 'JPAW.a'},
])
assert got == want, '\nGOT  %s\nWANT %s' % (got, want)
padnet = {}
for col, runs in BARE:
    for rn in runs:
        for xy in rn: assert padnet.setdefault(xy, find(xy)) == find(xy)

# ---- draw: bottom view, so column A is on the left and N on the right ----
S = 26; OX, OY = 250, 175; mm = S/2.54
MX, MY = 3.49*mm, 5.87*mm
def X(c): return OX + (COLS - c) * S
def Y(r): return OY + (r - 1) * S
o = []
def a(s): o.append(s)
def T(x, y, s, anchor='start', fill='#222', bold=False, size=12):
    a('<text x="%.1f" y="%.1f" text-anchor="%s" fill="%s" font-size="%s"%s>%s</text>' % (x, y, anchor, fill, size, ' font-weight="bold"' if bold else '', s))
W, Hh = 1330, int(Y(ROWS) + MY + 120)
a('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d" font-family="Helvetica, Arial, sans-serif" font-size="12">' % (W, Hh, W, Hh))
a('<rect width="%d" height="%d" fill="#ffffff"/>' % (W, Hh))
T(20, 28, 'Carrier board: 30-pin USB-C ESP32 soldered onto a 14 x 20 hole perfboard, parts underneath', bold=True, size=18)
T(20, 48, 'UNDERSIDE of the board, as you see it when you turn it over to solder: column A is on the left. Antenna end up, USB end down.', fill='#555')
T(20, 64, 'The ESP32 and the three connectors are on the other side (dashed). Everything else is on this side.', fill='#555')
bx0, bx1, by0, by1 = X(COLS) - MX, X(1) + MX, Y(1) - MY, Y(ROWS) + MY
a('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="3" fill="#dfe9d6" stroke="#5f7a4d" stroke-width="2"/>' % (bx0, by0, bx1 - bx0, by1 - by0))
for cx in (bx0 + 2*mm, bx1 - 2*mm):
    for cy in (by0 + 2*mm, by1 - 2*mm):
        a('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#fff" stroke="#6b7280" stroke-width="1.5"/>' % (cx, cy, 1.0*mm))
        a('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="#6b7280" stroke-width="1" stroke-dasharray="3 2"/>' % (cx, cy, 1.9*mm))
for c in range(1, COLS + 1): T(X(c), by0 - 7, L(c), 'middle', '#5f7a4d', True, 10)
for r in range(1, ROWS + 1): T(bx0 - 7, Y(r) + 3, str(ROWS + 1 - r), 'end', '#5f7a4d', size=9)
T(bx0 - 7, by0 - 7, 'row', 'end', '#5f7a4d', size=9)
# ESP32 outline, on the other side
e = 1.55*mm; ebot = Y(RP) + 9.2*mm; etop = ebot - 51.8*mm
a('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="4" fill="#1f2937" fill-opacity="0.06" stroke="#1f2937" stroke-width="1.5" stroke-dasharray="6 4"/>' % (X(HC2) - e, etop, X(HC) - X(HC2) + 2*e, ebot - etop))
T((X(HC) + X(HC2))/2, etop + 14, 'ESP32, other side: antenna end', 'middle', '#374151', size=10)
a('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#9ca3af" fill-opacity="0.45" stroke="#374151" stroke-dasharray="4 3"/>' % ((X(HC) + X(HC2))/2 - 4.47*mm, ebot - 5.1*mm, 8.94*mm, 7.3*mm))
T((X(HC) + X(HC2))/2, ebot + 2.2*mm + 14, 'USB-C', 'middle', '#374151', True, 10)
# holes
for c in range(1, COLS + 1):
    for r in range(1, ROWS + 1):
        a('<circle cx="%s" cy="%s" r="2.8" fill="#fff" stroke="#9db38c" stroke-width="1"/>' % (X(c), Y(r)))
# ESP32 pins coming through
for i, nm in enumerate(names):
    r = i + R0
    a('<rect x="%s" y="%s" width="13" height="13" fill="#111" opacity="%s"/>' % (X(HC) - 6.5, Y(r) - 6.5, '0.95' if (HC, r) in used else '0.45'))
    a('<rect x="%s" y="%s" width="13" height="13" fill="#111" opacity="0.45"/>' % (X(HC2) - 6.5, Y(r) - 6.5))
# bare runs
for col, runs in BARE:
    for rn in runs:
        (c1, r1), (c2, r2) = rn[0], rn[-1]
        a('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="4.5" stroke-linecap="round" opacity="0.85"/>' % (X(c1), Y(r1), X(c2), Y(r2), col))
# insulated wires (bends given as column / row offsets)
def curve(p, q, col, b):
    x1, y1, x2, y2 = X(p[0]), Y(p[1]), X(q[0]), Y(q[1])
    a('<path d="M%s,%s C%.1f,%.1f %.1f,%.1f %s,%s" fill="none" stroke="%s" stroke-width="3" stroke-dasharray="7 3"/>' % (x1, y1, x1 - b[0]*S, y1 + b[1]*S, x2 - b[2]*S, y2 + b[3]*S, x2, y2, col))
curve(WIRES[0][1], WIRES[0][2], WIRES[0][0], (-0.6, 4.2, 2.4, -1.0))
curve(WIRES[1][1], WIRES[1][2], WIRES[1][0], (-1.0, -3.2, 3.5, -1.6))
curve(WIRES[2][1], WIRES[2][2], WIRES[2][0], (-1.5, -1.4, 2.6, -0.2))
# components
def res(p, q, lab, fill='#d9b382', stroke='#7c5a2a', above=True):
    x1, y1, x2 = X(p[0]), Y(p[1]), X(q[0])
    a('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#6b7280" stroke-width="2"/>' % (x1, y1, x2, y1))
    xa, xb = sorted((x1, x2)); m = (xa + xb)/2; Lb = (xb - xa)*0.62
    a('<rect x="%.1f" y="%s" width="%.1f" height="12" rx="4" fill="%s" stroke="%s"/>' % (m - Lb/2, y1 - 6, Lb, fill, stroke))
    T(m, y1 - 9 if above else y1 + 19, lab, 'middle', '#111', True, 10)
    return m, y1, Lb
res(P['R1']['a'], P['R1']['b'], 'R1 220Ω')
res(P['R2']['a'], P['R2']['b'], 'R2 1k', above=False)
res(P['R3']['a'], P['R3']['b'], 'R3 15–22Ω', above=False)
m, dy, Lb = res(P['D1']['a'], P['D1']['k'], '← D1 stripe', '#f59e0b', '#7c2d12')
kx = m - Lb/2 + 4 if X(P['D1']['k'][0]) < X(P['D1']['a'][0]) else m + Lb/2 - 9
a('<rect x="%.1f" y="%s" width="5" height="12" fill="#111"/>' % (kx, dy - 6))
# transistor: flat face drawn on the right (towards column N) for E-B-C types
qc, qr = P['Q1']['B']
a('<path d="M%s,%s a%s,%s 0 0 0 0,%s z" fill="#374151" fill-opacity="0.35" stroke="#111"/>' % (X(qc) + 7, Y(qr) - S*1.15, S*1.15, S*1.15, S*2.3))
for pin, (c, r) in P['Q1'].items(): T(X(c) - S*0.42, Y(r) + 3.5, pin, 'end', '#111', True, 9)
T(X(qc) - S*1.25, Y(qr) - S*0.55, 'Q1', 'end', '#111', True, 10)
# capacitor lying flat, body towards column A
cx, cyp, cym = X(5), Y(P['C1']['+'][1]), Y(P['C1']['-'][1])
cy = (cyp + cym)/2
for yy in (cyp, cym): a('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#6b7280" stroke-width="2"/>' % (cx, yy, cx - S*0.4, yy))
a('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="5" fill="#1e3a8a" fill-opacity="0.80" stroke="#111"/>' % (cx - S*0.4 - S*4.33, cy - S*1.24, S*4.33, S*2.48))
T(cx - S*2.6, cy + 4, 'C1 lying flat', 'middle', '#fff', True, 10)
T(cx - S*0.95, cyp + 4, '+', 'middle', '#fff', True, 12); T(cx - S*0.95, cym + 4, '–', 'middle', '#fff', True, 12)
# connectors, on the other side
RX = bx1 + 12
def conn(part, lab, labels):
    (c1, r1), (c2, r2) = sorted(P[part].values(), key=lambda t: t[1])
    a('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="2" fill="#fef3c7" fill-opacity="0.55" stroke="#92400e" stroke-width="1.5" stroke-dasharray="5 3"/>' % (X(1) - S*1.15, Y(r1) - S*0.95, S*2.4, S*2.9))
    T(RX, (Y(r1) + Y(r2))/2 - 3, lab + ' connector (other side)', 'start', '#92400e', True, 11)
    T(RX, (Y(r1) + Y(r2))/2 + 11, ', '.join('%s %s' % (labels[pin], hole(P[part][pin])) for pin in labels), 'start', '#92400e', size=10)
conn('JMOT', 'MOTOR', {'+': 'red', '-': 'black'})
conn('JPAW', 'PAW', {'a': 'pin', 'b': 'pin'})
conn('JLED', 'LED', {'+': 'long leg', '-': 'short leg'})
# pads with a leg or wire end
for (c, r) in set(pins):
    if c == HC: continue
    a('<circle cx="%s" cy="%s" r="3.6" fill="#111"/>' % (X(c), Y(r)))
# the five ESP32 pins that are used, named on the left
for nm in ('D25', 'D26', 'D27', 'GND', 'VIN'):
    r = row[nm]
    T(bx0 - 26, Y(r) + 4, 'ESP32 pin %s is %s →' % (nm, hole((HC, r))), 'end', '#111', True, 10)
fy = by1 + 22
for s_ in ['A hole is named by its column letter and its row counted from the USB end: K4 is column K, 4th row up.',
           'The letters are printed on the top of your board. Dashed rings: the four M2 screws into the posts of the box.',
           'Place the ESP32 by counting rows: VIN must be in K4. One row out and the USB socket misses its opening in the box.']:
    T(20, fy, s_, 'start', '#555', size=11); fy += 15

# ---- legend ----
LX = 800; y = 104
def head(s):
    global y
    T(LX, y, s, bold=True, size=13); y += 20
def line_(s, ind=False):
    global y
    T(LX, y, ('  ' if ind else '• ') + s, fill='#444'); y += 17
head('How to read it')
a('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#111" stroke-width="4" stroke-linecap="round"/>' % (LX, y-4, LX+34, y-4)); T(LX+44, y, 'solid line: bare wire or solder bridge along the holes'); y += 18
a('<path d="M%s,%s h34" stroke="#16a34a" stroke-width="3" stroke-dasharray="7 3"/>' % (LX, y-4)); T(LX+44, y, 'dashed curve: insulated wire, joined only at its ends'); y += 18
a('<circle cx="%s" cy="%s" r="3.6" fill="#111"/>' % (LX+17, y-4)); T(LX+44, y, 'black dot: a component leg or wire end goes in this hole'); y += 18
a('<rect x="%s" y="%s" width="13" height="13" fill="#111" opacity="0.6"/>' % (LX+10, y-11)); T(LX+44, y, 'black square: an ESP32 pin coming through from the top'); y += 28
head('On the top of the board')
line_('ESP32 straight on the board, no socket strips: its two pin rows in')
line_('columns A and K, rows %d to %d. VIN is in K%d.' % (ROWS + 1 - (R0 + n - 1), ROWS + 1 - R0, ROWS + 1 - RP), True)
line_('MOTOR, PAW and LED connectors in column N.')
y += 12
head('Under the board')
partsT = [
 ('R1 220 Ω', '%s to %s' % (hole(P['R1']['a']), hole(P['R1']['b']))),
 ('R2 1 kΩ', '%s to %s' % (hole(P['R2']['a']), hole(P['R2']['b']))),
 ('R3 15–22 Ω', '%s to %s' % (hole(P['R3']['a']), hole(P['R3']['b']))),
 ('Q1 NPN', 'C in %s, B in %s, E in %s' % (hole(P['Q1']['C']), hole(P['Q1']['B']), hole(P['Q1']['E']))),
 ('', '2N2222 / PN2222 / 2N3904 / S8050: flat face towards column N'),
 ('', 'BC337 / BC547: flat face towards column A'),
 ('D1 1N4148', '%s to %s, stripe at %s' % (hole(P['D1']['a']), hole(P['D1']['k']), hole(P['D1']['k']))),
 ('C1 220 µF', '+ leg %s, – leg (stripe) %s, bent over to lie flat' % (hole(P['C1']['+']), hole(P['C1']['-']))),
 ('', 'towards column A. No wider than 6.3 mm'),
]
for nm, what in partsT:
    T(LX, y, nm, bold=True); T(LX+92, y, what); y += 17
y += 12
head('Three insulated wires, under the board')
for col, p, q, lab in WIRES:
    a('<path d="M%s,%s h26" stroke="%s" stroke-width="3" stroke-dasharray="7 3"/>' % (LX, y-4, col))
    T(LX+34, y, '%s: %s to %s' % (lab, hole(p), hole(q))); y += 17
y += 12
head('Build tips')
line_('Nothing under the board may hang lower than 7.5 mm. Push Q1 right down')
line_('or bend it over; the capacitor lies flat.', True)
line_('The holes are plated, so each part can be soldered from the side it is')
line_('on. Cut its legs to 2 mm first so they do not poke out under the ESP32.', True)
line_('Order: parts and wiring underneath, then the three connectors, then the')
line_('ESP32 last. Trim the ESP32 pins to 3 mm after soldering.', True)
line_('Black (row %d) and red (row %d) run side by side: check there is no bridge.' % (ROWS + 1 - RG, ROWS + 1 - RP))
line_('Check with a meter before powering it: no beep between VIN (K%d)' % (ROWS + 1 - RP))
line_('and GND (K%d).' % (ROWS + 1 - RG), True)
a('</svg>')
open(outp, 'w').write('\n'.join(o) + '\n')
print('ok: g=%s GND=%s VIN=%s' % (hole((HC, g)), hole((HC, RG)), hole((HC, RP))))
