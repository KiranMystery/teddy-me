// teddy-me: stitch-on heart window for the LED on the front of the bear.
//
// Two printed parts:
//   frame  the heart you sew on. A flat front plate with stitch holes lies on
//          the outside of the fabric; a short wall behind it goes through the
//          heart-shaped hole you cut in the bear.
//            style = "outline": the window is open. Glue diffuser film to the
//                               ledge behind it.
//            style = "full":    the window is closed by a thin lens. Print the
//                               whole frame in transparent PLA.
//   cup    a light box that pushes into the back of the frame and holds the
//          5 mm LED. Print it in white so it reflects.
//
//   openscad -D 'part="frame"' -D 'style="outline"' -o heart-frame-outline.stl heart.scad
//   (or just run ./build.sh)
//
// Both parts print flat on the bed with no supports: the frame front face
// down, the cup back face down.

/* [What to build] */
part  = "frame";      // "frame", "cup", "cup_placed" (cup where it sits in the frame), "assembly"
style = "outline";    // "outline" or "full"

/* [Size] */
heart_w   = 40;       // width of the lit window. Everything else follows from it

/* [Frame] */
ledge     = 1.5;      // rim behind the window that the film is glued to
skirt_wall= 1.2;      // wall that goes through the fabric
skirt_h   = 6.0;      // how far that wall stands behind the front plate
flange_w  = 5.5;      // width of the sewing flange outside the wall
flange_t  = 1.2;      // thickness of the front plate
lens_t    = 0.8;      // style "full": thickness of the window (4 layers at 0.2)
edge_soft = 0.4;      // chamfer on the front outside edge
stitch_d  = 1.6;      // stitch holes
stitch_pitch = 4.5;   // spacing between stitch holes (approximate, evened out)

/* [Cup and LED] */
cup_clear = 0.2;      // gap between the cup and the frame wall, per side
cup_wall  = 1.2;
cup_depth = 14;       // inside depth: LED tip to window distance sets the hot spot
back_t    = 2.0;      // cup back plate
led_d     = 5.1;      // hole for a 5 mm LED
led_flange_d = 6.3;   // recess for the LED's flange, in the outside of the back plate
led_flange_h = 1.0;
sleeve_h  = 4.0;      // sleeve inside the cup that grips the LED body
led_y     = 0;        // LED position above (+) or below (-) the middle of the heart, mm

// =====================================================================
$fn = 48;
// The heart is two round lobes and a small round tip joined by straight
// sides, so every outline below is a clean offset of it.
lobe_r = heart_w/3.8;                       // lobe radius
lobe_a = 0.9*lobe_r;                        // lobe centres at x = +/- lobe_a
tip_r  = 0.06*heart_w;                      // radius of the bottom tip
heart_h= 0.92*heart_w;                      // overall height of the window
tip_h  = heart_h - lobe_r - tip_r;          // tip circle centre below the lobe centres
y_mid  = (tip_h + tip_r - lobe_r)/2;        // shift that centres it top to bottom
// outward normal of the straight right-hand side (tangent to lobe and tip)
D_lt   = norm([lobe_a, tip_h]);
th_n   = atan2(-tip_h, -lobe_a) + acos((lobe_r - tip_r)/D_lt);   // angle of that normal
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

// 2D heart, grown outwards by g, with the cleft slightly rounded
module H(g = 0) {
    offset(r = g + 0.001)
        offset(r = -0.03*heart_w) offset(r = 0.03*heart_w)
            polygon(base);
}
skirt_in  = ledge;
skirt_out = ledge + skirt_wall;
flange_out= skirt_out + flange_w;
module flange2d(shrink = 0)
    offset(r = -shrink) offset(r = -3) offset(r = 3) H(flange_out);   // no sharp V at the cleft

// ---- stitch holes: evenly spaced along the curve half way across the flange
st_d = skirt_out + flange_w/2 + 0.2;
function nrm(i) = let (t = base[(i + 1) % N] - base[(i + N - 1) % N])
    norm(t) < 1e-9 ? [0, 0] : [t[1], -t[0]]/norm(t);
function dmin(p, i = 0, m = 1e9) = i >= N ? m : dmin(p, i + 1, min(m, norm(p - base[i])));
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
// the path starts and ends either side of the cleft, so its half-way point
// (leaving out the closing step across the cleft) is the tip: put a hole there
s_tip = cl[M - 1]/2;
function wrap(s) = s < 0 ? s + Ltot : (s >= Ltot ? s - Ltot : s);
holes = [for (k = [0 : n_st - 1]) at(wrap(s_tip + k*Ltot/n_st))];

led_xy = [0, led_y];

// =====================================================================
//  FRAME (front face on the bed)
// =====================================================================
module frame() {
    steps = 2;
    difference() {
        union() {
            // front plate with a stepped chamfer on its front outside edge
            for (i = [0 : steps - 1])
                translate([0, 0, i*edge_soft/steps])
                    linear_extrude(edge_soft/steps + 0.001) flange2d(edge_soft*(1 - i/steps));
            translate([0, 0, edge_soft]) linear_extrude(flange_t - edge_soft) flange2d();
            // wall through the fabric
            linear_extrude(flange_t + skirt_h) difference() { H(skirt_out); H(skirt_in); }
        }
        if (style == "full")
            translate([0, 0, lens_t]) linear_extrude(flange_t + skirt_h) H(0);
        else
            translate([0, 0, -1]) linear_extrude(flange_t + skirt_h + 2) H(0);
        for (p = holes) translate([p[0], p[1], -1]) cylinder(d = stitch_d, h = flange_t + 2, $fn = 16);
    }
}

// =====================================================================
//  CUP (back plate on the bed, open side up)
// =====================================================================
cup_o = skirt_in - cup_clear;
cup_i = cup_o - cup_wall;
cup_h = back_t + cup_depth;
module cup() {
    difference() {
        union() {
            linear_extrude(back_t) H(cup_o);
            linear_extrude(cup_h) difference() { H(cup_o); H(cup_i); }
            translate(led_xy) cylinder(d = led_d + 3.2, h = back_t + sleeve_h);
        }
        translate(led_xy) {
            translate([0, 0, -1]) cylinder(d = led_d, h = back_t + sleeve_h + 2);
            translate([0, 0, -0.01]) cylinder(d = led_flange_d, h = led_flange_h + 0.01);
        }
    }
}
// the cup where it sits when pushed home: rim against the ledge (and the film)
module cup_placed(film = 0.1) translate([0, 0, flange_t + film + cup_h]) mirror([0, 0, 1]) cup();

if (part == "frame") frame();
if (part == "cup") cup();
if (part == "cup_placed") cup_placed();
if (part == "assembly") {
    color(style == "full" ? "#ffd0d8" : "#e0314b") frame();
    color("#f4f4f4") cup_placed();
    // 5 mm LED
    color("#ff4b3e") translate([led_xy[0], led_xy[1], flange_t + 0.1 + cup_h]) mirror([0, 0, 1]) {
        cylinder(d = 5.8, h = 1);
        cylinder(d = 5, h = 6.1);
        translate([0, 0, 6.1]) sphere(d = 5);
    }
}
if (part != "none")
    echo(str("HEART window ", heart_w, " mm wide; ", n_st, " stitch holes about ",
             round(10*Ltot/n_st)/10, " mm apart; cup stands ",
             cup_h - skirt_h + 0.1, " mm behind the frame wall"));
