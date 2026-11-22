// teddy-me electronics box: everything wired inside the box.
//
// Block-level models of every part, placed with the same numbers the
// enclosure is built from (include <enclosure.scad>), plus colour-coded
// wires that follow the netlist. tools/build_assembly.py exports each
// part on its own (-D 'show="name"'), checks them against the box and
// builds the HTML viewer. Open this file in OpenSCAD to see it all (F5).
//
// Parts on the carrier sit in the perfboard holes given in
// carrier-38pin.svg / carrier-30pin.svg (repo root): hole (column, row),
// columns 1..18 across the 50 mm width, rows 1..24 along the 70 mm length,
// row 24 at the USB end. The links under the board follow that drawing too.
// (carrier = "compact" and "14x20": 14 columns, see carrier-compact-*.svg and
// carrier-14x20-38pin.svg.)

include <enclosure.scad>
part = "none";          // do not emit the print-orientation body/lid

show     = "all";       // one part name, or "all"
with_lid = false;       // "all" view: add the lid and its screws
dump     = false;       // echo the parts table and exit

// ------------------------------------------------------------------
//  Parts table: name, label for the viewer, colour, group
// ------------------------------------------------------------------
esp_label = board == "30pin" ? "ESP32 DevKit V1 (30-pin)" : "ESP32 DevKitC (38-pin)";
parts_all = [
 ["body",       "Box body (printed)",                 "#e7a23b", "box"],
 ["lid",        "Lid (printed)",                      "#f0b860", "box"],
 ["lid_screws", tuck ? "2 x M3x10 countersunk lid screws" : "4 x M3x10 countersunk lid screws", "#b9bec6", "box"],
 ["perfboard",  compact ? "Carrier perfboard, cut to 14 columns" : b14 ? "Carrier perfboard 60 x 40, 14 x 20 holes" : "Carrier perfboard 70 x 50", "#c9a66b", "carrier"],
 ["headers",    "Female headers",                     "#26262b", "carrier"],
 ["esp_pcb",    esp_label,                            "#15171c", "carrier"],
 ["esp_shield", "",                                   "#c5c9cf", "carrier"],
 ["esp_usb",    usb ? "ESP32 USB (power in and reflash)" : "ESP32 USB (reflash)", "#d9dce1", "carrier"],
 ["esp_btn",    "",                                   "#3b3f47", "carrier"],
 ["r1",         "R1 220 ohm (LED)",                   "#d9b382", "carrier"],
 ["r2",         "R2 1 k (base)",                      "#d9b382", "carrier"],
 ["r3",         "R3 15-22 ohm (motor +)",             "#d9b382", "carrier"],
 ["q1",         "Q1 NPN transistor",                  "#101014", "carrier"],
 ["d1",         "D1 1N4148 (stripe to 5 V)",          "#d8532b", "carrier"],
 ["c1",         lay14 ? "C1 220 uF, lying flat" : "C1 100-470 uF", "#27407e", "carrier"],
 ["j_pwr",      "5 V IN connector",                   "#f1ede0", "carrier"],
 ["j_motor",    "MOTOR connector",                    "#f1ede0", "carrier"],
 ["j_led",      "LED connector",                      "#f1ede0", "carrier"],
 ["j_paw",      "PAW connector",                      "#f1ede0", "carrier"],
 ["screws_m2",  b14 ? "4 x M2x5 self-tapping screws" : usb ? "3 x M2x5 self-tapping screws" : "6 x M2x5 self-tapping screws", "#b9bec6", "carrier"],
 ["chg_pcb",    "USB-C charger + 5 V boost (Adafruit 6106)", "#20304f", "power"],
 ["chg_usb",    "Charging port (USB-C)",              "#d9dce1", "power"],
 ["chg_jst",    "Battery socket + plug",              "#efe6c8", "power"],
 ["chg_term",   "5 V out screw terminal",             "#2e7fd6", "power"],
 ["chg_parts",  "",                                   "#2a2c31", "power"],
 ["battery",    "LiPo cell 3.7 V 2000 mAh",           "#8d98a8", "power"],
 ["switch",     "Slide switch (on/off)",              "#3d4250", "power"],
 ["sw_lever",   "",                                   "#f2f2f2", "power"],
 ["usb_cable",  "USB cable from the power bank",      "#2b2d33", "power"],
 ["cable_tie",  "Cable tie (strain relief)",          "#f4f4f4", "power"],
 ["motor",      "Coin vibration motor",               "#aeb4bd", "leads"],
 ["led",        "LED",                                "#ff4b3e", "leads"],
 ["button",     "Paw push button",                    "#4a4f5a", "leads"],
 ["w_5v",       "5 V (red)",                          "#e02424", "wires"],
 ["w_gnd",      "GND (black)",                        "#1a1a1a", "wires"],
 ["w_batt",     "Battery + (dark red)",               "#8c1414", "wires"],
 ["w_en",       "Switch to EN (white)",               "#f4f4f4", "wires"],
 ["w_led",      "LED signal, GPIO 25 (green)",        "#22b14c", "wires"],
 ["w_drv",      "Motor drive, GPIO 26 to base (yellow)", "#e8b800", "wires"],
 ["w_motp",     "Motor +, after R3 (orange)",         "#f07a13", "wires"],
 ["w_mot",      "Motor -, to collector (purple)",     "#8b3fd6", "wires"],
 ["w_paw",      "Paw button, GPIO 27 (blue)",         "#1f6fe0", "wires"],
 ["plug_esp",   "USB plug in the ESP32 (check only)", "#777777", "check"],
 ["plug_chg",   "USB-C plug in the charger (check only)", "#777777", "check"],
 ["keepout",    "3 mm of solder joints and links under the carrier (check only)", "#cc3333", "check"],
];
// power = "usb" has no charger, battery, switch or 5 V IN connector;
// power = "battery" has no power cable and tie.
only_battery = ["chg_pcb", "chg_usb", "chg_jst", "chg_term", "chg_parts", "battery", "switch",
                "sw_lever", "w_batt", "w_en", "plug_chg", "j_pwr"];
only_usb     = ["usb_cable", "cable_tie"];
not_compact  = ["screws_m2"];        // the cut board has no corner holes
function has(list, x) = len([for (e = list) if (e == x) 1]) > 0;
parts = [for (p = parts_all) if (!has(usb ? only_battery : only_usb, p[0])
                                 && !(compact && has(not_compact, p[0]))) p];
assert(!(lay14 && motor_in_box), "motor_in_box is not laid out for carrier = \"compact\" or \"14x20\"");
if (dump) for (p = parts) echo(str("PART|", p[0], "|", p[1], "|", p[2], "|", p[3]));

// ------------------------------------------------------------------
//  Shared positions
// ------------------------------------------------------------------
wd  = 1.0;                         // hook-up wire
ro  = board == "30pin" ? 3 : 0;    // the 30-pin layout is the same, 3 rows nearer the USB
// perfboard hole (column, row) -> position; dz above the top face
function hx(r) = px0 + gx0 + (n_rows - r)*2.54;
function hy(c) = py0 + gy0 + (n_cols - c)*2.54;
function ht(c, r, dz = 0) = [hx(r), hy(c), zt + dz];     // on the top face
function hu(c, r, dz = 0.6) = [hx(r), hy(c), zs - dz];   // under the board

esp_x0 = px0 + esp_x0r;                                  // USB end of the ESP32 PCB
esp_yc = py0 + esp_center_y;
esp_zb = zt + header_h + pin_spacer_h;                   // underside of the ESP32 PCB
r_usb  = compact ? n_rows - 1 : n_rows;                  // hole row of the USB-end pin (5V / VIN)
pin_r0 = r_usb - esp_pins + 1;                           // hole row of the antenna-end pin
r25 = row25; r26 = r25 + 1; r27 = r25 + 2;               // rows of GPIO 25 / 26 / 27
rgnd = pin_r0 + 13;                                      // GND is the 14th pin
hdr_cols = lay14 ? [3, 13] : [8, 18];                    // the two socket strips
jst_top = 10.5;                                          // top of a plugged connector

module wire(pts, d = wd) {
    for (i = [0 : len(pts) - 2]) if (norm(pts[i + 1] - pts[i]) > 0.01) hull() {
        translate(pts[i]) sphere(d = d, $fn = 10);
        translate(pts[i + 1]) sphere(d = d, $fn = 10);
    }
}
module P(name) {
    if (show == name || (show == "all" && name != "lid" && name != "lid_screws"
                         && name != "plug_esp" && name != "plug_chg" && name != "keepout")
        || (show == "all" && with_lid && (name == "lid" || name == "lid_screws")))
        for (p = parts) if (p[0] == name) color(p[2]) children();
}

// ------------------------------------------------------------------
//  Box
// ------------------------------------------------------------------
P("body") body();
P("lid")  lid();
P("lid_screws") for (b = boss_xy) translate([b[0], b[1], H_in + lid_t]) {
    cs = (lid_head_d - 3)/2;
    translate([0, 0, -cs]) cylinder(d1 = 3, d2 = lid_head_d, h = cs, $fn = 24);
    translate([0, 0, -lid_screw_len]) cylinder(d = 2.4, h = lid_screw_len - cs + 0.01, $fn = 16);
}

// ------------------------------------------------------------------
//  Carrier board and ESP32
// ------------------------------------------------------------------
P("perfboard") difference() {
    translate([px0, py0, zs]) cube(pf);
    if (!compact) for (h = perf_hole_xy) translate([h[0], h[1], zs - 1]) cylinder(d = 2.0, h = 4, $fn = 16);
}
module pin_rows(z, h, w = 2.54) for (c = hdr_cols)
    translate([hx(r_usb) - 1.27 + (2.54 - w)/2, hy(c) - w/2, z]) cube([esp_pins*2.54 - (2.54 - w), w, h]);
P("headers") pin_rows(zt, header_h);
P("esp_pcb") {
    translate([esp_x0, esp_yc - esp_w/2, esp_zb]) cube([esp_pcb_len, esp_w, esp_pcb_t]);
    pin_rows(zt + header_h, pin_spacer_h + 0.01, lay14 ? 2.5 : 2.54);   // the board's own pin strips
    // WROOM module PCB, with the antenna at the far end
    translate([esp_x0 + esp_len - 25.5, esp_yc - 9, esp_zb + esp_pcb_t - 0.01]) cube([25.5, 18, 0.8]);
}
P("esp_shield")
    translate([esp_x0 + esp_len - 25.5 + 0.9, esp_yc - 7.9, esp_zb + esp_pcb_t + 0.8]) cube([17.6, 15.8, 2.4]);
usb_e = esp_usb_type == "c" ? [7.35, 8.94, 3.3] : [5.6, 7.5, 2.6];   // depth, width, height
P("esp_usb")
    translate([esp_mouth_x, esp_yc - usb_e[1]/2, esp_zb + esp_pcb_t + esp_usb_h - usb_e[2]/2])
        cube(usb_e);
P("esp_btn") for (s = [-1, 1])
    translate([esp_x0 + 2.5, esp_yc + s*9.5 - 1.5, esp_zb + esp_pcb_t]) cube([4, 3, 1.6]);

// axial part lying between hole (ca, r) and hole (cb, r)
module axial(ca, cb, r, d = 2.3, l = 6.0) {
    translate([hx(r), (hy(ca) + hy(cb))/2, zt + 0.3 + d/2]) rotate([90, 0, 0]) {
        cylinder(d = d, h = l, center = true, $fn = 20);
        cylinder(d = 0.5, h = abs(hy(ca) - hy(cb)), center = true, $fn = 8);
    }
    for (c = [ca, cb]) translate([hx(r), hy(c), zt]) cylinder(d = 0.5, h = 0.3 + d/2, $fn = 8);
}
// Compact carrier (carrier-compact-*.svg): the small parts sit under the ESP32
// in columns 4 to 12; g is the row of GPIO 25, rp the row of the 5V / VIN pin.
g = r25;  rp = r_usb;
qc = lay14 ? 9 : 2;  qr = lay14 ? g + 1 : 10 + ro;      // Q1 base leg
if (lay14) {
    P("r1") axial(4, 7, g);
    P("r2") axial(4, 7, g + 1);
    P("r3") axial(9, 12, rp);
    P("d1") axial(9, 12, g - 1, 1.9, 3.9);
} else {
    P("r1") axial(7, 4, r25);
    P("r2") axial(7, 4, 10 + ro);
    P("r3") axial(2, 6, 3 + ro);
    P("d1") axial(3, 6, 7 + ro, 1.9, 3.9);
}
P("q1") {                                   // three legs in one column: C, B, E
    translate(ht(qc, qr, 2.5)) rotate([0, 0, 90]) intersection() {
        cylinder(d = 4.6, h = 4.6, $fn = 24);
        translate([-2.3, -2.3, 0]) cube([4.6, 3.6, 4.6]);
    }
    for (r = [qr - 1, qr, qr + 1]) translate(ht(qc, r, 0.02)) cylinder(d = 0.5, h = 2.6, $fn = 8);
}
c1r = 1 + ro;
c1_lie = [6.3, 11];                         // compact: diameter and length, lying flat
P("c1") if (lay14) {                      // legs in column 4, rows rp-1 and rp, body towards column 9
    translate([(hx(rp) + hx(rp - 1))/2, hy(4) - 1.0, zt + 0.2 + c1_lie[0]/2]) rotate([90, 0, 0])
        cylinder(d = c1_lie[0], h = c1_lie[1], $fn = 32);
    for (r = [rp - 1, rp]) hull() {
        translate(ht(4, r, 0.3)) sphere(d = 0.5, $fn = 8);
        translate([hx(r), hy(4) - 1.0, zt + 0.2 + c1_lie[0]/2]) sphere(d = 0.5, $fn = 8);
    }
} else translate([hx(c1r), (hy(1) + hy(2))/2, zt + 0.3]) cylinder(d = 8, h = 12, $fn = 32);

// 2-pin JST-XH header with its plug, pins in holes (ca, r) and (cb, r)
module jst(ca, cb, r) {
    yc = (hy(ca) + hy(cb))/2;
    translate([hx(r) - 2.875, yc - 3.7, zt + 0.02]) cube([5.75, 7.4, 7.0]);
    translate([hx(r) - 2.25, yc - 3.0, zt + 7.0]) cube([4.5, 6.0, jst_top - 7.0]);
}
// the same connector with its two pins one above the other in column c (rows
// ra and rb). Its body is modelled 6.8 mm deep, the worst case either way round.
module jst_v(c, ra, rb) {
    xc = (hx(ra) + hx(rb))/2;
    translate([xc - 3.7, hy(c) - 3.4, zt + 0.02]) cube([7.4, 6.8, 7.0]);
    translate([xc - 3.0, hy(c) - 2.25, zt + 7.0]) cube([6.0, 4.5, jst_top - 7.0]);
}
if (lay14) {
    P("j_motor") jst_v(1, g - 3, g - 2);
    P("j_paw")   jst_v(1, g + 2, g + 3);
    P("j_led")   jst_v(1, g + 6, g + 7);
} else {
    P("j_pwr")   jst(1, 2, 24);
    P("j_motor") jst(3, 4, 5 + ro);
    P("j_led")   jst(1, 2, r25);
    P("j_paw")   jst(1, 2, 17 + ro);
}

module m2(x, y, z, len = 5) translate([x, y, z]) {
    cylinder(d = 3.8, h = 1.4, $fn = 20);
    translate([0, 0, -len]) cylinder(d = 1.6, h = len + 0.01, $fn = 12);
}
// Carrier: only the two gutter-side corners get a screw. In the carrier
// drawings C1 and the 5 V IN connector sit over the two battery-side corner
// holes; that edge is held by the fins under the lid instead.
P("screws_m2") if (b14) {
    // 14 x 20 board: nothing sits over any corner hole, so all four get a screw
    for (h = perf_hole_xy) m2(h[0], h[1], zt);
} else {
    for (h = perf_hole_xy) if (h[1] < py0 + pf[1]/2) m2(h[0], h[1], zt);
    if (usb) {
        // with no 5 V IN connector, the far corner at the USB end is free too
        for (h = perf_hole_xy) if (h[1] > py0 + pf[1]/2 && h[0] < px0 + pf[0]/2) m2(h[0], h[1], zt);
    } else
        for (h = chg_holes) m2(chg_x0 + h[0], chg_y0 + h[1], chg_z + chg[2]);
}

// ------------------------------------------------------------------
//  Power: charger board, battery, switch
// ------------------------------------------------------------------
chg_top = chg_z + chg[2];
function cb(x, y, z = 0) = [chg_x0 + x, chg_y0 + y, chg_top + z];   // point on the charger board
P("chg_pcb") difference() {
    translate([chg_x0, chg_y0, chg_z]) linear_extrude(chg[2]) rrect(0, 0, chg[0], chg[1], 2.54);
    for (h = chg_holes) translate([chg_x0 + h[0], chg_y0 + h[1], chg_z - 1]) cylinder(d = 2.5, h = 4, $fn = 16);
}
P("chg_usb") translate([chg_x0 - chg_usb_overhang, up_y - 4.47, up_z - 1.63]) cube([7.35, 8.94, 3.26]);
P("chg_jst") {
    translate(cb(chg_jst[0], chg_jst[1])) cube([chg_jst[2], chg_jst[3], 6.0]);
    translate(cb(chg_jst[0] + 1, chg_jst[1] + chg_jst[3], 0.8)) cube([6, 2.5, 4.2]);   // battery plug
}
P("chg_term") translate(cb(chg_term[0], chg_term[1])) cube([chg_term[2], chg_term[3], chg_top_h]);
P("chg_parts") {
    translate(cb(18.96, 13.69)) cube([5, 5, 4.5]);                      // inductor
    translate(cb(13.2, 6.2)) cube([3, 3, 1]);
    for (x = chg_pad_x) translate(cb(x, chg_pad_y)) cylinder(d = 1.7, h = 0.15, $fn = 12);
}
batt_x0 = blk + batt_lead_room;
batt_ym = batt_y0 + batt_slot/2;
P("battery") translate([batt_x0, batt_ym - batt[2]/2, 0.05])
    cube([batt[0], batt[2], batt[1]]);

P("switch") {
    translate([sw_x + 0.02, sw_yc - sw_body[0]/2, sw_zc - sw_body[1]/2]) cube([sw_body[2], sw_body[0], sw_body[1]]);
    for (dy = [-2.5, 0, 2.5]) translate([sw_x + sw_body[2], sw_yc + dy - 0.25, sw_zc - 0.15]) cube([3.0, 0.5, 0.3]);
}
P("sw_lever") translate([sw_x - sw_lever_len, sw_yc + sw_travel/2 - sw_lever_w/2, sw_zc - sw_lever_w/2])
    cube([sw_lever_len + 0.02, sw_lever_w, sw_lever_w]);

// ------------------------------------------------------------------
//  Links under the carrier, as drawn in carrier-*.svg
//  (bare links hug the board; insulated wires hang a little lower)
// ------------------------------------------------------------------
if (lay14) {
    gb = max(rgnd, g + 6);                                  // last row of the GND run in column 2
    P("w_gnd") {
        wire([hu(2, rgnd), hu(9, rgnd)]);                   // GND pin: out to column 2, in to column 9
        wire([hu(9, g + 2), hu(9, rgnd)]);                  // Q1 emitter
        wire([hu(4, rgnd), hu(4, rp - 1)]);                 // C1 -
        wire([hu(2, g + 3), hu(2, gb)]);                    // GND run beside the connectors
        wire([hu(1, g + 3), hu(2, g + 3)]);                 // PAW
        wire([hu(1, g + 6), hu(2, g + 6)]);                 // LED -
    }
    P("w_5v")  wire([hu(3, rp), hu(9, rp)]);                // 5V pin to C1 + and R3
    P("w_led") {
        wire([hu(3, g), hu(4, g)]);
        wire([hu(7, g), hu(7, g, 1.8), hu(1, g + 7, 1.8), hu(1, g + 7)]);          // insulated, to LED +
    }
    P("w_drv") { wire([hu(3, g + 1), hu(4, g + 1)]); wire([hu(7, g + 1), hu(9, g + 1)]); }
    P("w_mot") {
        wire([hu(9, g - 1), hu(9, g)]);
        wire([hu(9, g - 1), hu(9, g - 1, 2.9), hu(1, g - 2, 2.9), hu(1, g - 2)]);  // insulated, to MOTOR -
    }
    P("w_motp") {
        wire([hu(12, g - 1), hu(12, rp)]);
        wire([hu(12, g - 1), hu(12, g - 1, 2.3), hu(1, g - 3, 2.3), hu(1, g - 3)]); // insulated, to MOTOR +
    }
    P("w_paw") wire([hu(1, g + 2), hu(3, g + 2)]);
} else {
    P("w_gnd") {
        wire([hu(1, c1r), hu(1, 24)]);                          // GND bus down column 1
        wire([hu(1, rgnd), hu(8, rgnd)]);                       // to the ESP32 GND pin
        wire([hu(2, 11 + ro), hu(1, 11 + ro)]);                 // Q1 emitter
    }
    P("w_5v") {
        wire([hu(2, 24), hu(8, 24)]);                           // 5 V IN + to the ESP32 5V pin
        wire([hu(5, 24), hu(5, 24, 2.0), hu(2, 2 + ro, 2.0), hu(2, 2 + ro)]);   // up to C1 / R3
        wire([hu(2, c1r), hu(2, 3 + ro)]);
    }
    P("w_motp") { wire([hu(6, 3 + ro), hu(6, 7 + ro)]); wire([hu(6, 5 + ro), hu(4, 5 + ro)]); }
    P("w_mot")  wire([hu(3, 5 + ro), hu(3, 9 + ro), hu(2, 9 + ro)]);
    P("w_drv") {
        wire([hu(8, r26), hu(8, r26, 2.0), hu(7, 10 + ro, 2.0), hu(7, 10 + ro)]);
        wire([hu(4, 10 + ro), hu(2, 10 + ro)]);
    }
    P("w_led") { wire([hu(8, r25), hu(7, r25)]); wire([hu(4, r25), hu(2, r25)]); }
    P("w_paw") wire([hu(8, r27), hu(8, r27, 3.2), hu(2, 17 + ro, 3.2), hu(2, 17 + ro)]);
}

// ------------------------------------------------------------------
//  Power and switch wiring
// ------------------------------------------------------------------
sw_pin_x = sw_x + sw_body[2] + 3.0;
pad_y = chg_y0 + chg_pad_y;
pad_g  = chg_x0 + chg_pad_x[4];                       // G pad
pad_en = chg_x0 + chg_pad_x[7];                       // EN pad
gut_y = 2.6;                                          // where wires climb in the gutter
z_pw_r = H_in - 2.3;  z_pw_k = H_in - 3.5;            // 5 V pair crossing above the ESP32
xt_k = blk + 1.2;  xt_r = blk + 2.8;                  // where the pair turns out of the gutter
term_x = chg_x0 + chg_term[0] + chg_term[2];          // wire-entry face of the screw terminal
term_z = chg_top + 3.5;
tp = [chg_y0 + chg_term_pads[0][1], chg_y0 + chg_term_pads[1][1]];   // + and - ways
rise_r = term_x + 2.6;  rise_k = term_x + 1.2;        // where each wire climbs the gutter
batt_plug = [chg_x0 + chg_jst[0] + 4, chg_y0 + chg_jst[1] + chg_jst[3] + 2.5, chg_top + 2.9];
under = 1.2;                                          // switch wires run under the charger board

// screw terminal + / - -> up the gutter -> across the USB end of the ESP32
// -> the 5 V IN plug
if (!usb) P("w_5v") wire([[term_x - 2, tp[0], term_z], [rise_r, tp[0], term_z], [rise_r, gut_y, term_z],
                [rise_r, gut_y, z_pw_r], [xt_r, gut_y, z_pw_r], [xt_r, hy(2), z_pw_r],
                [hx(24) + 0.9, hy(2), z_pw_r], [hx(24) + 0.9, hy(2), zt + jst_top]]);
if (!usb) P("w_gnd") {
    wire([[term_x - 2, tp[1], term_z], [rise_k, tp[1], term_z], [rise_k, tp[1], term_z + 1.6],
          [rise_k, gut_y, term_z + 1.6], [rise_k, gut_y, z_pw_k], [xt_k, gut_y, z_pw_k],
          [xt_k, hy(1), z_pw_k], [hx(24) - 0.9, hy(1), z_pw_k], [hx(24) - 0.9, hy(1), zt + jst_top]]);
    // switch centre pin -> under the charger board -> its G pad
    wire([[sw_pin_x, sw_yc, sw_zc], [sw_pin_x + 0.6, sw_yc, sw_zc], [sw_pin_x + 0.6, sw_yc, under],
          [pad_g, chg_y0 + chg[1] + 3, under], [pad_g, pad_y, under], [pad_g, pad_y, chg_top + 0.4]]);
    // battery -
    wire([[batt_x0, batt_ym, 7.0], [8.6, batt_ym, 7.0], [8.6, div_y0 - 1.6, 7.0],
          [batt_plug[0] - 1, div_y0 - 1.6, 7.0], [batt_plug[0] - 1, batt_plug[1], batt_plug[2]]], 1.3);
}
P("w_batt")
    wire([[batt_x0, batt_ym, 8.4], [8.6, batt_ym, 8.4], [8.6, div_y0 - 1.6, 8.4],
          [batt_plug[0] + 1, div_y0 - 1.6, 8.4], [batt_plug[0] + 1, batt_plug[1], batt_plug[2]]], 1.3);
// switch outer pin -> under the charger board -> its EN pad
P("w_en")
    wire([[sw_pin_x, sw_yc + 2.5, sw_zc], [sw_pin_x + 0.6, sw_yc + 2.5, sw_zc], [sw_pin_x + 0.6, sw_yc + 2.5, under],
          [pad_en, chg_y0 + chg[1] + 3, under], [pad_en, pad_y, under], [pad_en, pad_y, chg_top + 0.4]]);

// ------------------------------------------------------------------
//  power = "usb": the power bank's cable. It plugs into the ESP32, loops
//  back and is tied to the long wall beside the ESP32 through the two slots.
// ------------------------------------------------------------------
plug_len  = 20;                                   // moulded plug body
cab_y     = -wall - cable_d/2 - 0.5;              // cable centre along the wall
cab_z     = (tie_z[0] + tie_z[1] + tie_slot[1])/2;
loop_x    = esp_mouth_x - 1.0 - plug_len - 9;     // where the U-turn starts
loop_r    = (ue_y - cab_y)/2;
loop_yc   = (ue_y + cab_y)/2;
P("usb_cable") {
    translate([esp_mouth_x - 1.0 - plug_len, ue_y - 5.3, ue_z - 3.5]) cube([plug_len, 10.6, 7.0]);
    translate([esp_mouth_x - 1.0 - plug_len - 8, ue_y, ue_z]) rotate([0, 90, 0])
        cylinder(d1 = cable_d + 0.6, d2 = 6, h = 8.01, $fn = 24);          // strain boot
    wire(concat(
        [[esp_mouth_x - 1.0 - plug_len - 7, ue_y, ue_z], [loop_x, ue_y, ue_z]],
        [for (a = [15 : 15 : 165])
            [loop_x - loop_r*sin(a), loop_yc + loop_r*cos(a), ue_z + (cab_z - ue_z)*a/180]],
        [[loop_x, cab_y, cab_z], [tie_x0 + tie_slot[0] + 40, cab_y, cab_z]]), cable_d);
}
tie_t = 1.2;  tie_w = 3.6;                         // cable tie section
tie_xc = tie_x0 + tie_slot[0]/2;
tie_yi = 1.0;                                      // inside the box, in the gutter
tie_yo = cab_y - cable_d/2 - 0.4 - tie_t;          // outside, beyond the cable
P("cable_tie") {
    for (z = tie_z) translate([tie_xc - tie_w/2, tie_yo, z + (tie_slot[1] - tie_t)/2])
        cube([tie_w, tie_yi + tie_t - tie_yo, tie_t]);
    for (y = [tie_yo, tie_yi]) translate([tie_xc - tie_w/2, y, tie_z[0] + (tie_slot[1] - tie_t)/2])
        cube([tie_w, tie_t, tie_z[1] - tie_z[0] + tie_t]);
}

// ------------------------------------------------------------------
//  The three leads (two wires each, stacked where the lid pinches them)
// ------------------------------------------------------------------
z_lo = H_in - notch_d + wire_d/2;
z_hi = H_in - wire_d/2;
x_jog = fence_x0 + fence_t + (L_in - fence_x0 - fence_t)/2;
x_out = L_in + wall;
dev_x = x_out + 34;
dev_z = 16;
// lead k: 0 = paw, 1 = motor, 2 = LED
lead_row = [17 + ro, 5 + ro, r25];
lead_col = [[2, 1], [4, 3], [2, 1]];                  // [signal / + pin, return pin]
// compact: both pins of a connector are in column 1, on two rows
lead_rc  = [[g + 2, g + 3], [g - 3, g - 2], [g + 7, g + 6]];
function lead_pin(k, s) = lay14 ? [hx(lead_rc[k][s]), hy(1)] : [hx(lead_row[k]), hy(lead_col[k][s])];
// Which exit each lead takes. On the compact carrier the lead that starts
// nearest the USB end takes the exit furthest from the connectors, so no lead
// has to cross another.
function exit_of(k) = lay14 ? [1, 2, 0][k] : (motor_in_box ? (k == 2 ? 1 : 0) : k);
function dev_y(k) = W_in/2 - 22 + 22*exit_of(k);
// s = 0: signal wire (lower in the slot), s = 1: return wire (upper)
function lead_path(k, s) =
    let (x = lead_pin(k, s)[0], yj = lead_pin(k, s)[1], z = s == 0 ? z_lo : z_hi,
         fy = fence_notch_y(exit_of(k)), wy = wall_notch_y(exit_of(k)), sy = s == 0 ? -1 : 1)
    [[x, yj, zt + jst_top], [x, yj, z], [x, fy, z], [x_jog, fy, z], [x_jog, wy, z],
     [x_out + 9, wy, z], [x_out + 20, (wy + dev_y(k))/2, (z + dev_z)/2 + 2],
     [dev_x - 6, dev_y(k) + sy, dev_z + 1], [dev_x - 1, dev_y(k) + sy, dev_z]];

mot_c = [motor_x0 + (motor_d + 0.4)/2, 0.2 + motor_t/2, 0.05 + motor_d/2];   // motor in its pocket
function motor_in_path(s) =
    let (x = mot_c[0] + (s == 0 ? -0.8 : 0.8), z = s == 0 ? H_in - 3.6 : H_in - 2.2,
         xj = lead_pin(1, s)[0], yj = lead_pin(1, s)[1])
    [[x, mot_c[1], mot_c[2] + motor_d/2 - 0.3], [x, 3.9, 13], [x, 3.9, z], [x, yj, z], [xj, yj, z], [xj, yj, zt + jst_top]];

P("motor") {
    if (motor_in_box) translate(mot_c) rotate([90, 0, 0]) cylinder(d = motor_d, h = motor_t, center = true, $fn = 32);
    else translate([dev_x + 4, dev_y(1), dev_z - 1.5]) cylinder(d = motor_d, h = motor_t, $fn = 32);
}
P("led") translate([dev_x, dev_y(2), dev_z]) rotate([0, 90, 0]) {
    cylinder(d = 5.8, h = 1, $fn = 24);
    cylinder(d = 5, h = 6, $fn = 24);
    translate([0, 0, 6]) sphere(d = 5, $fn = 24);
}
P("button") translate([dev_x, dev_y(0), dev_z]) {
    translate([-1, -3, -1.75]) cube([6, 6, 3.5]);
    translate([2, 0, 1.7]) cylinder(d = 3.5, h = 1.5, $fn = 20);
}
P("w_paw")  wire(lead_path(0, 0), wire_d);
P("w_led")  wire(lead_path(2, 0), wire_d);
P("w_gnd")  { wire(lead_path(0, 1), wire_d); wire(lead_path(2, 1), wire_d); }
P("w_motp") if (motor_in_box) wire(motor_in_path(0), wire_d); else wire(lead_path(1, 0), wire_d);
P("w_mot")  if (motor_in_box) wire(motor_in_path(1), wire_d); else wire(lead_path(1, 1), wire_d);

// ------------------------------------------------------------------
//  Check-only parts: a worst-case USB plug pushed fully into each socket.
//  Micro-USB spec maximum overmould is 10.6 x 8.5 mm; USB-C 12.35 x 6.5.
//  The moulded body stops about 1 mm short of the socket mouth.
// ------------------------------------------------------------------
module usb_plug(mouth_x, yc, zc, body) {
    translate([mouth_x - 1.0 - 25, yc - body[0]/2, zc - body[1]/2]) cube([25, body[0], body[1]]);
}
P("plug_esp") usb_plug(esp_mouth_x, ue_y, ue_z, esp_usb_type == "c" ? [12.35, 6.5] : [10.6, 8.5]);
P("plug_chg") usb_plug(chg_x0 - chg_usb_overhang, up_y, up_z, [12.35, 6.5]);

// Check-only: the space the carrier's own solder joints and under-board links
// need, 3 mm deep, under every hole column that carries a joint: columns 1 to 8
// (parts and the EN-side header) and columns 17 and 18 (the other header, on
// either board width). Between them, under the ESP32, the board is bare, and
// that is where the charger's screw terminal sits.
P("keepout") if (compact) {
    // compact: joints everywhere except the spare rows (1 and n_rows), spare
    // column 14, and the free holes beside GPIO 25 where a support post stands
    xa = px0 + 2.54;  xb = px0 + pf[0] - 2.54;  ys = hy(3) + 1.3;
    box(xa, xb, hy(13) - 1.3, ys, zs - 3, zs - 0.01);
    box(xa, hx(g) - 1.7, ys, py0 + pf[1], zs - 3, zs - 0.01);
    box(hx(g) + 1.7, xb, ys, py0 + pf[1], zs - 3, zs - 0.01);
} else if (b14) {
    // 14 x 20 board: joints from row 2 to row 20 and from column 1 to column 13.
    // The four corner posts stand in the bare margin outside that
    box(hx(n_rows) - 1.3, hx(2) + 1.3, hy(13) - 1.3, hy(1) + 1.3, zs - 3, zs - 0.01);
} else {
    box(px0, px0 + pf[0], hy(8) - 1.3, py0 + pf[1], zs - 3, zs - 0.01);
    box(px0, px0 + pf[0], hy(18) - 1.3, hy(17) + 1.3, zs - 3, zs - 0.01);
}
