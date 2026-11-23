// teddy-me: light-up heart that fits like a safety eye.
//
// Two printed parts and no sewing:
//   heart  a solid domed heart for TRANSLUCENT red filament, with a threaded
//          hole in its flat back. It sits on the outside of the fabric
//   bolt   a hollow threaded bolt with a wide head. It goes through a hole in
//          the fabric from the inside of the bear and screws into the heart, so
//          the fabric is clamped between the two
// The 5 mm LED pushes in through the hollow bolt until its tip is just behind
// the front of the heart. Nothing shows from the front.
//
//   openscad -D 'part="heart"' -o heart.stl heart.scad     (or just run ./build.sh)
//
// Both parts print flat on the bed with no supports: the heart on its back,
// the bolt on its head.

/* [What to build] */
part = "heart";       // "heart" or "bolt" (print orientation). For the checks:
                      // "bolt_placed", "led", "assembly"
cut  = false;         // "assembly": slice it open through the LED
gap  = 1.0;           // "bolt_placed" and "assembly": fabric thickness between heart and bolt

/* [Size] */
heart_w  = 20;        // width of the heart

/* [Shape] */
roof     = 1.4;       // translucent plastic in front of the LED tip
dome_h   = undef;     // height of the rounded part. undef = 18% of the width
dome_run = 0.75;      // how far in from the edge the dome keeps rising, as a share
                      // of the distance from the edge to the LED. It is cut back
                      // automatically on small hearts, where the threaded hole
                      // needs the sides to stay steep
layer    = 0.2;       // the dome is built in steps this tall: print at 0.2 or 0.1

/* [Thread]  one coarse rounded thread, the same on every size */
th_d     = 9.6;       // outside diameter of the bolt's thread
th_pitch = 2.0;
th_e     = 0.35;      // half the thread depth
th_clear = 0.35;      // air between bolt and hole, per side. Too tight: 0.45. Too loose: 0.25
stem_len = 5.0;       // threaded length of the bolt

/* [Bolt] */
bore_d   = 6.1;       // hole through the bolt: the LED's 5.8 mm flange passes
head_d   = 16;        // head, which presses on the back of the fabric
head_t   = 2.0;
grip_n   = 8;         // finger notches round the head

/* [LED]  MEASURE */
led_d    = 5.0;
led_flange_d = 5.8;
led_len  = 8.6;       // overall, flange included

// =====================================================================
$fn = 48;
hole_h = stem_len + 0.2;                    // depth of the threaded hole
H      = hole_h + roof;                     // height of the heart at the LED
dome   = is_undef(dome_h) ? min(0.18*heart_w, H - 1.5) : dome_h;
base_h = H - dome;                          // straight-sided part below the dome
th_r   = th_d/2 - th_e;                     // the thread is a circle this big, swept round off-centre
r_hole = th_d/2 + th_clear;                 // widest reach of the threaded hole
assert(th_r - th_e - bore_d/2 >= 0.9, "bolt wall too thin: raise th_d or lower bore_d");

// The heart is two round lobes and a small round tip joined by straight sides.
lobe_r = heart_w/3.8;
lobe_a = 0.9*lobe_r;
tip_r  = 0.06*heart_w;
heart_h= 0.92*heart_w;
tip_h  = heart_h - lobe_r - tip_r;
y_mid  = (tip_h + tip_r - lobe_r)/2;
D_lt   = norm([lobe_a, tip_h]);
th_n   = atan2(-tip_h, -lobe_a) + acos((lobe_r - tip_r)/D_lt);
th_c   = atan2(sqrt(lobe_r*lobe_r - lobe_a*lobe_a), -lobe_a);
seg    = 1.0;
function arc(c, r, a0, a1) = let (n = max(2, ceil(abs(a1 - a0)*PI/180*r/seg)))
    [for (i = [0 : n - 1]) c + r*[cos(a0 + (a1 - a0)*i/n), sin(a0 + (a1 - a0)*i/n)]];
function line(p, q) = let (n = max(1, ceil(norm(q - p)/seg))) [for (i = [0 : n - 1]) p + (q - p)*i/n];
c_r = [lobe_a, y_mid];  c_l = [-lobe_a, y_mid];  c_t = [0, y_mid - tip_h];
base = concat(
    arc(c_l, lobe_r, 180 - th_c, 180 - th_n),
    line(c_l + lobe_r*[cos(180 - th_n), sin(180 - th_n)], c_t + tip_r*[cos(180 - th_n), sin(180 - th_n)]),
    arc(c_t, tip_r, 180 - th_n, 360 + th_n),
    line(c_t + tip_r*[cos(th_n), sin(th_n)], c_r + lobe_r*[cos(th_n), sin(th_n)]),
    arc(c_r, lobe_r, th_n, th_c));
N = len(base);
function dmin(p, i = 0, m = 1e9) = i >= N ? m : dmin(p, i + 1, min(m, norm(p - base[i])));

// 2D heart with the cleft slightly rounded, and the same shrunk inwards by d
module H2() offset(r = -0.03*heart_w) offset(r = 0.03*heart_w) polygon(base);
module Hin(d) { s = 1.0; offset(r = s) offset(r = -s - d) polygon(base); }

// ---- the bolt and LED go at the point on the centre line furthest from the edge
cands  = [for (y = [-heart_h/2 : 0.25 : heart_h/2]) [dmin([0, y]), y]];
d_best = max([for (c = cands) c[0]]);
c_xy   = [0, [for (c = cands) if (c[0] == d_best) c[1]][0]];
d_edge = dmin(c_xy);                        // from the bolt's axis to the nearest edge
side_wall = d_edge - r_hole;                // plastic beside the threaded hole, at its thinnest
assert(side_wall >= 0.8, "heart too small for this thread");

// ---- dome: it must still be above the threaded hole where that comes nearest the edge
u_req  = max(0, min(0.98, (hole_h + 0.3 - base_h)/dome));
run_max= u_req > 0 ? (side_wall - 0.8)/(1 - sqrt(1 - u_req*u_req)) : 1e9;
d_run  = min(dome_run*(d_edge - 1.0), run_max);
n_steps = round(dome/layer);
function inset(k) = let (u = (k + 0.5)/n_steps) d_run*(1 - sqrt(1 - u*u));   // quarter-ellipse profile

// one turn per th_pitch: a circle swept round off-centre gives a smooth rounded
// thread that prints without supports, as a bolt or as a hole
module thread(h, grow = 0)
    linear_extrude(height = h, twist = -360*h/th_pitch, slices = ceil(h/0.1), convexity = 6)
        translate([th_e, 0]) circle(r = th_r + grow, $fn = 60);

// =====================================================================
//  THE HEART (back on the bed)
// =====================================================================
module heart() {
    difference() {
        union() {
            linear_extrude(base_h) H2();
            for (k = [0 : n_steps - 1]) translate([0, 0, base_h + k*dome/n_steps - 0.001])
                linear_extrude(dome/n_steps + 0.001) Hin(inset(k));
        }
        translate([c_xy[0], c_xy[1], -0.01]) {
            thread(hole_h + 0.01, th_clear);
            cylinder(r1 = r_hole + 0.5, r2 = r_hole - 0.3, h = 0.8);   // lead-in for the bolt
        }
    }
}

// =====================================================================
//  THE BOLT, where it sits: head `g` below the back of the heart
// =====================================================================
module bolt_at(g = 0) translate([c_xy[0], c_xy[1], -g]) {
    difference() {
        union() {
            // turned by the same angle the thread advances over g, so it stays in mesh
            rotate(-360*g/th_pitch) intersection() {
                thread(stem_len);
                union() {                                   // blunt lead-in at the tip
                    cylinder(r = th_d/2 + 1, h = stem_len - 0.8);
                    translate([0, 0, stem_len - 0.8]) cylinder(r1 = th_d/2 + 0.1, r2 = th_d/2 - 1.0, h = 0.8);
                }
            }
            translate([0, 0, -head_t]) difference() {
                union() {
                    translate([0, 0, 0.4]) cylinder(d = head_d, h = head_t - 0.4);
                    cylinder(d1 = head_d - 0.8, d2 = head_d, h = 0.4);
                }
                for (i = [0 : grip_n - 1]) rotate(360*i/grip_n) translate([head_d/2 + 0.7, 0, -1])
                    cylinder(r = 1.6, h = head_t + 2, $fn = 24);
            }
        }
        translate([0, 0, -head_t - 1]) cylinder(d = bore_d, h = head_t + stem_len + 2);
        translate([0, 0, -head_t - 0.01]) cylinder(d1 = bore_d + 1.2, d2 = bore_d, h = 0.6);
    }
}
// a 5 mm LED pushed in until its tip touches the end of the hole
module led() translate([c_xy[0], c_xy[1], hole_h - led_len]) {
    cylinder(d = led_flange_d, h = 1);
    cylinder(d = led_d, h = led_len - led_d/2);
    translate([0, 0, led_len - led_d/2]) sphere(d = led_d);
}

if (part == "heart") heart();
if (part == "bolt") translate([-c_xy[0], -c_xy[1], head_t]) bolt_at(0);   // head on the bed, thread up
if (part == "bolt_placed") bolt_at(gap);
if (part == "led") led();
if (part == "assembly") difference() {
    union() { color("#d81e2c", 0.9) heart(); color("#f2f2f2") bolt_at(gap); color("#ff8a80") led(); }
    if (cut) translate([0, -200, -50]) cube([200, 400, 100]);
}
if (part != "none")
    echo(str("HEART ", heart_w, " x ", heart_h, " mm, ", H, " mm tall (straight sides ", base_h, ", dome ", dome,
             "); ", roof, " mm of plastic in front of the LED; thinnest wall beside the thread ",
             round(100*side_wall)/100, " mm; bolt head ", head_d, " mm, thread ", th_d, " mm, takes fabric up to ",
             stem_len - 2.5, " mm thick"));
