// teddy-me: squeeze pad for the paw button.
//
// A small round pod that turns a 6 x 6 mm tactile switch into a button you can
// find through stuffing. Three printed parts:
//   base   holds the switch (legs bent out flat) and the two wires
//   plate  a loose disc that rests on the switch plunger. Press it anywhere:
//          in the middle it pushes straight down, at an edge it tips, catches
//          under the ring on the far side and levers the plunger down
//   ring   slips over the base and keeps the plate in. Glue it on
//
//   openscad -D 'part="base"' -o paw-pad-base.stl paw-pad.scad
//   (or just run ./build.sh)
//
// All three print flat on the bed with no supports.

/* [What to build] */
part  = "base";   // "base", "plate", "ring" (print orientation), or "assembly".
                  // Check poses, in place: "base_placed", "ring_placed", "switch",
                  // "plate_rest", "plate_pressed", "plate_lifted", "plate_edge"
cut   = false;    // "assembly": slice it open to show the inside

/* [Size] */
pad_d = 30;       // diameter of the plate you press

/* [Tactile switch]  MEASURE */
sw_side   = 6.0;  // body is square: side length
sw_body_h = 3.5;  // body height
sw_h      = 5.0;  // underside of the body to the top of the plunger. Common
                  // 6 mm switches are 4.3, 5, 7 or 9.5 mm: measure yours
sw_plunger_d = 3.5;
sw_travel = 0.35; // how far the plunger moves before it clicks (0.25 typical)

/* [Fits] */
lift      = 0.8;  // free play of the plate above the plunger. Generous on
                  // purpose: if it were too small a tall switch would be held down
proud     = 1.4;  // how far the plate stands above the ring
flange_over = 1.2;// plate flange beyond the plate
flange_t  = 1.2;
bore_clear= 0.3;  // plate flange to base wall, per side
top_clear = 0.4;  // plate to ring opening, per side
ring_clear= 0.15; // ring to base wall, per side (glued)
wall      = 1.2;  // base wall
ring_wall = 1.2;
lip_t     = 1.2;  // ring lip that holds the plate in
floor_t   = 1.2;
skirt_max = 5.0;  // how far the ring comes down the base wall

/* [Switch pocket and wires] */
rib_h     = 2.5;  // height of the ribs that locate the switch
rib_t     = 1.2;
sw_clear  = 0.15; // switch body to ribs, per side
slot      = [3.4, 1.8];  // wire exit in the wall: width, height (two 1.4 mm wires)
gate      = 1.7;  // gap between the two posts that pinch the wires

/* [Sewing tabs] */
tabs      = 4;    // number of tabs with a hole for a stitch (0 = none)
tab_len   = 4.5;  // how far each tab sticks out beyond the ring
tab_t     = 1.6;
tab_hole  = 2.0;

// =====================================================================
$fn = 96;
r_pad  = pad_d/2;
r_fl   = r_pad + flange_over;          // plate flange
r_in   = r_fl + bore_clear;            // inside of the base wall
r_base = r_in + wall;                  // outside of the base wall
r_ring = r_base + ring_clear + ring_wall;
wall_top = sw_h + flange_t + lift;     // top of the base wall = underside of the ring lip
plate_t  = flange_t + lift + lip_t + proud;
skirt  = min(skirt_max, wall_top - slot[1] - 0.4);   // never covers the wire exit
half   = sw_side/2 + sw_clear;
// The wires normally leave past the switch legs, at +x. On a small pod the
// two posts would land on the legs there, so the exit moves round a quarter
// turn to a side of the switch that has no legs.
exit_a = (r_in - 3.2 - 1.3 < sw_side/2 + 3 + 0.5) ? 90 : 0;
post_r = exit_a == 0 ? r_in - 3.2 : max(r_in - 3.2, half + rib_t + 1.3 + 0.6);
e      = 0.01;
assert(sw_h - rib_h >= sw_travel + 1.2 + 0.5, "ribs too tall for this switch");
if (part != "none")
    echo(str("PAW PAD plate ", pad_d, " mm; whole pod ", 2*r_ring, " mm across",
             tabs > 0 ? str(" (", 2*(r_ring + tab_len), " over the tabs)") : "",
             ", ", floor_t + sw_h + plate_t, " mm tall"));

// z = 0 is the top of the base floor, where the switch sits.
module base() {
    difference() {
        translate([0, 0, -floor_t]) cylinder(r = r_base, h = floor_t + wall_top);
        cylinder(r = r_in, h = wall_top + 1);
        // wire exit, at +x (at +y on a small pod)
        rotate(exit_a) translate([r_in - 1, -slot[0]/2, 0]) cube([wall + 2, slot[0], slot[1]]);
    }
    // switch pocket: the legs leave on the +x and -x sides, two per side
    for (s = [-1, 1]) {
        translate([-sw_side/2, s*(half + rib_t/2) - rib_t/2, -e]) cube([sw_side, rib_t, rib_h + e]);
        translate([s*(half + rib_t/2) - rib_t/2, -1.2, -e]) cube([rib_t, 2.4, rib_h + e]);
    }
    // two posts that pinch the wires before they leave
    rotate(exit_a) for (s = [-1, 1])
        translate([post_r, s*(gate/2 + 1.3), -e]) cylinder(d = 2.6, h = rib_h + e, $fn = 24);
    // sewing tabs, between the wire exit and the next one round
    if (tabs > 0) for (i = [0 : tabs - 1]) rotate(360*(i + 0.5)/tabs) difference() {
        hull() {
            translate([r_ring + tab_len - 3, 0, -floor_t]) cylinder(r = 3, h = tab_t, $fn = 32);
            translate([r_base - 1, -4, -floor_t]) cube([1, 8, tab_t]);
        }
        translate([r_ring + tab_len - 3, 0, -floor_t - 1]) cylinder(d = tab_hole, h = tab_t + 2, $fn = 20);
    }
}

// the plate where it rests: underside on the plunger
module plate() {
    ch = 0.8;
    translate([0, 0, sw_h]) {
        cylinder(r = r_fl, h = flange_t);
        cylinder(r = r_pad, h = plate_t - ch);
        translate([0, 0, plate_t - ch]) cylinder(r1 = r_pad, r2 = r_pad - ch, h = ch);
    }
}

// the ring where it sits: lip on top of the base wall
module ring() {
    ch = 0.6;
    difference() {
        union() {
            translate([0, 0, wall_top - skirt]) cylinder(r = r_ring, h = skirt + lip_t - ch);
            translate([0, 0, wall_top + lip_t - ch]) cylinder(r1 = r_ring, r2 = r_ring - ch, h = ch);
        }
        translate([0, 0, wall_top - skirt - 1]) cylinder(r = r_base + ring_clear, h = skirt + 1);
        translate([0, 0, wall_top - 1]) cylinder(r = r_pad + top_clear, h = lip_t + 2);
    }
}

// block model of the switch with its legs bent out flat
module switch() {
    translate([-sw_side/2, -sw_side/2, 0]) cube([sw_side, sw_side, sw_body_h]);
    cylinder(d = sw_plunger_d, h = sw_h, $fn = 32);
    for (sx = [-1, 1], sy = [-1, 1])
        translate([sx > 0 ? sw_side/2 - e : -sw_side/2 - 3, sy*2.25 - 0.35, 0]) cube([3 + e, 0.7, 0.3]);
}

// the plate tipped by a press on its +x edge: first it tips about the plunger
// until the far edge catches under the ring, then about that edge until the
// plunger has gone down by `press`
module plate_edge(press = sw_travel + 0.15) {
    th1 = asin((lift - 0.05)/r_fl);
    th2 = atan(press/r_fl);
    B = [-r_fl*cos(th1), 0, sw_h + flange_t + lift - 0.05];
    translate(B) rotate([0, th2, 0]) translate(-B)
        translate([0, 0, sw_h]) rotate([0, th1, 0]) translate([0, 0, -sw_h]) plate();
}

if (part == "base")  translate([0, 0, floor_t]) base();
if (part == "plate") translate([0, 0, -sw_h]) plate();
if (part == "ring")  translate([0, 0, wall_top + lip_t]) rotate([180, 0, 0]) ring();
if (part == "base_placed")   base();
if (part == "ring_placed")   ring();
if (part == "switch")        switch();
if (part == "plate_rest")    plate();
if (part == "plate_pressed") translate([0, 0, -(sw_travel + 0.15)]) plate();
if (part == "plate_lifted")  translate([0, 0, lift - 0.02]) plate();
if (part == "plate_edge")    plate_edge();
if (part == "assembly") difference() {
    union() {
        color("#e7a23b") base();
        color("#f0b860") ring();
        color("#f6d9c9") plate();
        color("#2b2d33") switch();
    }
    if (cut) translate([-100, -200, -50]) cube([200, 200, 100]);
}
