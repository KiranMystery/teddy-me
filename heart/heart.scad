// teddy-me: stitch-on heart for the LED on the front of the bear.
//
// One printed piece, meant for red filament: a domed heart with a flat rim of
// stitch holes round it. The 5 mm LED pushes in from the back and its tip
// pokes out through the middle of the dome.
//
//   openscad -o heart.stl heart.scad            (or just run ./build.sh)
//
// Prints flat on its back with no supports. Sew it onto the outside of the
// fabric; only the LED's two wires go through the fabric, behind the middle.

/* [What to build] */
part = "heart";       // "heart", or for the checks: "led" (a 5 mm LED where it sits), "assembly"
cut  = false;         // "assembly": slice it open through the LED

/* [Size] */
heart_w  = 40;        // width of the domed heart. The rim adds to this

/* [Dome] */
dome_h   = undef;     // height of the dome above the rim. undef = 7 mm, or a
                      // quarter of the width on hearts under 28 mm
dome_run = 1.0;       // how far in from the edge the dome keeps rising, as a
                      // share of the distance from the edge to the LED (0.5 = a
                      // steep edge and a wide flat top, 1.0 = rounded all the way)
layer    = 0.2;       // the dome is built in steps this tall: print at 0.2 or 0.1

/* [Rim] */
flange_w = undef;     // width of the sewing rim. undef = 5.5 mm, less on
                      // hearts under 27 mm (4.5 mm on a 20 mm heart)
flange_t = 1.2;       // its thickness
edge_soft= 0.4;       // chamfer on the rim's top outside edge
stitch_d = 1.6;       // stitch holes
stitch_pitch = 4.5;   // spacing between stitch holes (approximate, evened out)

/* [LED]  MEASURE */
led_d        = 5.1;   // hole for a 5 mm LED
led_flange_d = 6.3;   // recess for the LED's flange (5.8 mm) at the back
led_len      = 7.6;   // LED length in front of its flange (8.6 mm overall)
led_poke     = 3.5;   // how far the LED tip stands out of the dome
led_y        = undef; // LED position above (+) / below (-) the middle of the heart.
                      // undef = the thickest point on the centre line

// =====================================================================
$fn = 48;
dome = is_undef(dome_h) ? min(7.0, heart_w/4) : dome_h;
rim  = is_undef(flange_w) ? min(5.5, 1.5 + 0.15*heart_w) : flange_w;
cleft_fill = min(3, 0.1*heart_w);           // rounds the notch in the rim's outline
// The heart is two round lobes and a small round tip joined by straight sides.
lobe_r = heart_w/3.8;                       // lobe radius
lobe_a = 0.9*lobe_r;                        // lobe centres at x = +/- lobe_a
tip_r  = 0.06*heart_w;                      // radius of the bottom tip
heart_h= 0.92*heart_w;                      // overall height of the dome outline
tip_h  = heart_h - lobe_r - tip_r;          // tip circle centre below the lobe centres
y_mid  = (tip_h + tip_r - lobe_r)/2;        // shift that centres it top to bottom
D_lt   = norm([lobe_a, tip_h]);
th_n   = atan2(-tip_h, -lobe_a) + acos((lobe_r - tip_r)/D_lt);   // normal of the straight right side
th_c   = atan2(sqrt(lobe_r*lobe_r - lobe_a*lobe_a), -lobe_a);    // cleft, seen from the right lobe
seg    = 1.0;                               // point spacing along the outline, mm
function arc(c, r, a0, a1) = let (n = max(2, ceil(abs(a1 - a0)*PI/180*r/seg)))
    [for (i = [0 : n - 1]) c + r*[cos(a0 + (a1 - a0)*i/n), sin(a0 + (a1 - a0)*i/n)]];
function line(p, q) = let (n = max(1, ceil(norm(q - p)/seg))) [for (i = [0 : n - 1]) p + (q - p)*i/n];
c_r = [lobe_a, y_mid];  c_l = [-lobe_a, y_mid];  c_t = [0, y_mid - tip_h];
// anticlockwise, starting in the cleft: left lobe, left side, tip, right side, right lobe
base = concat(
    arc(c_l, lobe_r, 180 - th_c, 180 - th_n),
    line(c_l + lobe_r*[cos(180 - th_n), sin(180 - th_n)], c_t + tip_r*[cos(180 - th_n), sin(180 - th_n)]),
    arc(c_t, tip_r, 180 - th_n, 360 + th_n),
    line(c_t + tip_r*[cos(th_n), sin(th_n)], c_r + lobe_r*[cos(th_n), sin(th_n)]),
    arc(c_r, lobe_r, th_n, th_c));
N = len(base);
function dmin(p, i = 0, m = 1e9) = i >= N ? m : dmin(p, i + 1, min(m, norm(p - base[i])));

// 2D heart grown outwards by g (the rim), with the cleft slightly rounded
module H(g = 0) {
    offset(r = g + 0.001)
        offset(r = -0.03*heart_w) offset(r = 0.03*heart_w)
            polygon(base);
}
// 2D heart shrunk inwards by d (one step of the dome), corners kept round
module Hin(d) { s = 1.0; offset(r = s) offset(r = -s - d) polygon(base); }
module flange2d(shrink = 0)
    offset(r = -shrink) offset(r = -cleft_fill) offset(r = cleft_fill) H(rim);   // no sharp V at the cleft

// ---- where the LED goes: the point on the centre line furthest from the edge
cands  = [for (y = [-heart_h/2 : 0.25 : heart_h/2]) [dmin([0, y]), y]];
d_best = max([for (c = cands) c[0]]);
y_best = [for (c = cands) if (c[0] == d_best) c[1]][0];
led_xy = [0, is_undef(led_y) ? y_best : led_y];
d_led  = dmin(led_xy);                      // distance from the LED to the edge
d_run  = dome_run*(d_led - led_flange_d/2); // the dome is at full height from here inwards
assert(d_run > 2, "heart too small for a dome round the LED");

// ---- stitch holes: evenly spaced along the middle of the rim
st_d = rim/2 + 0.2;
function nrm(i) = let (t = base[(i + 1) % N] - base[(i + N - 1) % N])
    norm(t) < 1e-9 ? [0, 0] : [t[1], -t[0]]/norm(t);
// offset curve, minus the part that folds over itself in the cleft
path = [for (i = [0 : N - 1]) let (p = base[i] + st_d*nrm(i)) if (dmin(p) >= st_d - 0.15) p];
M = len(path);
function cum(i = 0, acc = [0]) = i >= M ? acc
    : cum(i + 1, concat(acc, [acc[i] + norm(path[(i + 1) % M] - path[i])]));
cl = cum();
Ltot = cl[M];
n_st = round(Ltot/stitch_pitch);
function at(s, j = 0) = (j >= M - 1 || cl[j + 1] >= s)
    ? let (a = path[j], b = path[(j + 1) % M], f = cl[j + 1] > cl[j] ? (s - cl[j])/(cl[j + 1] - cl[j]) : 0)
      a + f*(b - a)
    : at(s, j + 1);
s_tip = cl[M - 1]/2;                        // half way round is the tip: put a hole there
function wrap(s) = s < 0 ? s + Ltot : (s >= Ltot ? s - Ltot : s);
holes = [for (k = [0 : n_st - 1]) at(wrap(s_tip + k*Ltot/n_st))];

// ---- LED seat
top_z    = flange_t + dome;                 // top of the dome, where the LED comes out
recess_h = top_z + led_poke - led_len;      // depth of the flange recess in the back
grip     = top_z - recess_h;                // length of the hole that holds the LED body
assert(recess_h >= 1.2, "LED cannot poke out that far: lower led_poke or dome_h");
assert(grip >= 2, "too little material round the LED: raise dome_h or lower led_poke");

// =====================================================================
//  THE HEART (back on the bed)
// =====================================================================
n_steps = round(dome/layer);
function inset(k) = let (u = (k + 0.5)/n_steps) d_run*(1 - sqrt(1 - u*u));   // quarter-ellipse profile
module heart() {
    difference() {
        union() {
            // rim, with a stepped chamfer on its top outside edge
            linear_extrude(flange_t - edge_soft) flange2d();
            for (i = [0, 1]) translate([0, 0, flange_t - edge_soft + i*edge_soft/2])
                linear_extrude(edge_soft/2 + 0.001) flange2d(edge_soft*(i + 1)/2);
            // dome: one slice per layer, each a little smaller than the last
            for (k = [0 : n_steps - 1]) translate([0, 0, flange_t + k*dome/n_steps - 0.001])
                linear_extrude(dome/n_steps + 0.001) Hin(inset(k));
        }
        for (p = holes) translate([p[0], p[1], -1]) cylinder(d = stitch_d, h = flange_t + 2, $fn = 16);
        translate([led_xy[0], led_xy[1], -1]) cylinder(d = led_d, h = top_z + 2);
        translate([led_xy[0], led_xy[1], -0.01]) cylinder(d = led_flange_d, h = recess_h + 0.01);
    }
}
// a 5 mm LED where it sits: flange against the top of the recess
module led() translate([led_xy[0], led_xy[1], recess_h]) {
    translate([0, 0, -1]) cylinder(d = 5.8, h = 1);
    cylinder(d = 5, h = led_len - 2.5);
    translate([0, 0, led_len - 2.5]) sphere(d = 5);
}

if (part == "heart") heart();
if (part == "led") led();
if (part == "assembly") difference() {
    union() { color("#d81e2c") heart(); color("#ff8a80") led(); }
    if (cut) translate([0, -200, -50]) cube([200, 400, 100]);
}
if (part != "none")
    echo(str("HEART dome ", heart_w, " x ", heart_h, " mm, ", top_z, " mm tall; with the rim ",
             heart_w + 2*rim, " x ", heart_h + 2*rim, " mm; ", n_st, " stitch holes about ",
             round(10*Ltot/n_st)/10, " mm apart; LED at y = ", led_xy[1], ", ",
             round(10*d_led)/10, " mm from the edge, pokes out ", led_poke, " mm"));
