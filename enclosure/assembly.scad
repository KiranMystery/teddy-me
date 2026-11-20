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

include <enclosure.scad>
part = "none";          // do not emit the print-orientation body/lid

show     = "all";       // one part name, or "all"
with_lid = false;       // "all" view: add the lid and its screws
dump     = false;       // echo the parts table and exit

// ------------------------------------------------------------------
//  Parts table: name, label for the viewer, colour, group
// ------------------------------------------------------------------
esp_label = board == "30pin" ? "ESP32 DevKit V1 (30-pin)" : "ESP32 DevKitC (38-pin)";
parts = [
 ["body",       "Box body (printed)",                 "#e7a23b", "box"],
 ["lid",        "Lid (printed)",                      "#f0b860", "box"],
 ["lid_screws", "4 x M3x10 countersunk lid screws",   "#b9bec6", "box"],
 ["perfboard",  "Carrier perfboard 70 x 50",          "#c9a66b", "carrier"],
 ["headers",    "Female headers",                     "#26262b", "carrier"],
 ["esp_pcb",    esp_label,                            "#15171c", "carrier"],
 ["esp_shield", "",                                   "#c5c9cf", "carrier"],
 ["esp_usb",    "ESP32 USB (reflash)",                "#d9dce1", "carrier"],
 ["esp_btn",    "",                                   "#3b3f47", "carrier"],
 ["r1",         "R1 220 ohm (LED)",                   "#d9b382", "carrier"],
 ["r2",         "R2 1 k (base)",                      "#d9b382", "carrier"],
 ["r3",         "R3 15-22 ohm (motor +)",             "#d9b382", "carrier"],
 ["q1",         "Q1 NPN transistor",                  "#101014", "carrier"],
 ["d1",         "D1 1N4148 (stripe to 5 V)",          "#d8532b", "carrier"],
 ["c1",         "C1 100-470 uF",                      "#27407e", "carrier"],
 ["j_pwr",      "5 V IN connector",                   "#f1ede0", "carrier"],
 ["j_motor",    "MOTOR connector",                    "#f1ede0", "carrier"],
 ["j_led",      "LED connector",                      "#f1ede0", "carrier"],
 ["j_paw",      "PAW connector",                      "#f1ede0", "carrier"],
 ["screws_m2",  "6 x M2x5 self-tapping screws",       "#b9bec6", "carrier"],
 ["chg_pcb",    "USB-C charger + 5 V boost (Adafruit 6106)", "#20304f", "power"],
 ["chg_usb",    "Charging port (USB-C)",              "#d9dce1", "power"],
 ["chg_jst",    "Battery socket + plug",              "#efe6c8", "power"],
 ["chg_term",   "5 V out screw terminal",             "#2e7fd6", "power"],
 ["chg_parts",  "",                                   "#2a2c31", "power"],
 ["battery",    "LiPo cell 3.7 V 2000 mAh",           "#8d98a8", "power"],
 ["switch",     "Slide switch (on/off)",              "#3d4250", "power"],
 ["sw_lever",   "",                                   "#f2f2f2", "power"],
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
if (dump) for (p = parts) echo(str("PART|", p[0], "|", p[1], "|", p[2], "|", p[3]));

// ------------------------------------------------------------------
//  Shared positions
// ------------------------------------------------------------------
wd  = 1.0;                         // hook-up wire
ro  = board == "30pin" ? 3 : 0;    // the 30-pin layout is the same, 3 rows nearer the USB
// perfboard hole (column, row) -> position; dz above the top face
function hx(r) = px0 + perf_grid_x0 + (24 - r)*2.54;
function hy(c) = py0 + perf_grid_y0 + (18 - c)*2.54;
function ht(c, r, dz = 0) = [hx(r), hy(c), zt + dz];     // on the top face
function hu(c, r, dz = 0.6) = [hx(r), hy(c), zs - dz];   // under the board

esp_x0 = px0 + esp_x0r;                                  // USB end of the ESP32 PCB
esp_yc = py0 + esp_center_y;
esp_zb = zt + header_h + pin_spacer_h;                   // underside of the ESP32 PCB
pin_r0 = 24 - esp_pins + 1;                              // hole row of the antenna-end pin
r25 = 14 + ro; r26 = 15 + ro; r27 = 16 + ro;             // rows of GPIO 25 / 26 / 27
rgnd = pin_r0 + 13;                                      // GND is the 14th pin
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
    translate([px0, py0, zs]) cube(perf);
    for (h = perf_hole_xy) translate([h[0], h[1], zs - 1]) cylinder(d = 2.0, h = 4, $fn = 16);
}
module pin_rows(z, h) for (c = [8, 18])
    translate([hx(24) - 1.27, hy(c) - 1.27, z]) cube([esp_pins*2.54, 2.54, h]);
P("headers") pin_rows(zt, header_h);
P("esp_pcb") {
    translate([esp_x0, esp_yc - esp_w/2, esp_zb]) cube([esp_pcb_len, esp_w, esp_pcb_t]);
    pin_rows(zt + header_h, pin_spacer_h + 0.01);          // the board's own pin strips
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
P("r1") axial(7, 4, r25);
P("r2") axial(7, 4, 10 + ro);
P("r3") axial(2, 6, 3 + ro);
P("d1") axial(3, 6, 7 + ro, 1.9, 3.9);
P("q1") {                                   // legs in column 2: C, B, E on three rows
    translate(ht(2, 10 + ro, 2.5)) rotate([0, 0, 90]) intersection() {
        cylinder(d = 4.6, h = 4.6, $fn = 24);
        translate([-2.3, -2.3, 0]) cube([4.6, 3.6, 4.6]);
    }
    for (r = [9, 10, 11]) translate(ht(2, r + ro, 0.02)) cylinder(d = 0.5, h = 2.6, $fn = 8);
}
c1r = 1 + ro;
P("c1") translate([hx(c1r), (hy(1) + hy(2))/2, zt + 0.3]) cylinder(d = 8, h = 12, $fn = 32);

// 2-pin JST-XH header with its plug, pins in holes (ca, r) and (cb, r)
module jst(ca, cb, r) {
    yc = (hy(ca) + hy(cb))/2;
    translate([hx(r) - 2.875, yc - 3.7, zt + 0.02]) cube([5.75, 7.4, 7.0]);
    translate([hx(r) - 2.25, yc - 3.0, zt + 7.0]) cube([4.5, 6.0, jst_top - 7.0]);
}
P("j_pwr")   jst(1, 2, 24);
P("j_motor") jst(3, 4, 5 + ro);
P("j_led")   jst(1, 2, r25);
P("j_paw")   jst(1, 2, 17 + ro);

module m2(x, y, z, len = 5) translate([x, y, z]) {
    cylinder(d = 3.8, h = 1.4, $fn = 20);
    translate([0, 0, -len]) cylinder(d = 1.6, h = len + 0.01, $fn = 12);
}
// Carrier: only the two gutter-side corners get a screw. In the carrier
// drawings C1 and the 5 V IN connector sit over the two battery-side corner
// holes; that edge is held by the fins under the lid instead.
P("screws_m2") {
    for (h = perf_hole_xy) if (h[1] < py0 + perf[1]/2) m2(h[0], h[1], zt);
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
P("w_5v") wire([[term_x - 2, tp[0], term_z], [rise_r, tp[0], term_z], [rise_r, gut_y, term_z],
                [rise_r, gut_y, z_pw_r], [xt_r, gut_y, z_pw_r], [xt_r, hy(2), z_pw_r],
                [hx(24) + 0.9, hy(2), z_pw_r], [hx(24) + 0.9, hy(2), zt + jst_top]]);
P("w_gnd") {
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
//  The three leads (two wires each, stacked where the lid pinches them)
// ------------------------------------------------------------------
z_lo = H_in - notch_d + wire_d/2;
z_hi = H_in - wire_d/2;
x_jog = fence_x0 + fence_t + (L_in - fence_x0 - fence_t)/2;
x_out = L_in + wall;
dev_x = x_out + 34;
dev_z = 16;
// lead k: 0 = paw, 1 = motor, 2 = LED, in the order of their exits
lead_row = [17 + ro, 5 + ro, r25];
lead_col = [[2, 1], [4, 3], [2, 1]];                  // [signal / + pin, return pin]
function exit_of(k) = motor_in_box ? (k == 2 ? 1 : 0) : k;
function dev_y(k) = W_in/2 - 22 + 22*exit_of(k);
// s = 0: signal wire (lower in the slot), s = 1: return wire (upper)
function lead_path(k, s) =
    let (x = hx(lead_row[k]), yj = hy(lead_col[k][s]), z = s == 0 ? z_lo : z_hi,
         fy = fence_notch_y(exit_of(k)), wy = wall_notch_y(exit_of(k)), sy = s == 0 ? -1 : 1)
    [[x, yj, zt + jst_top], [x, yj, z], [x, fy, z], [x_jog, fy, z], [x_jog, wy, z],
     [x_out + 9, wy, z], [x_out + 20, (wy + dev_y(k))/2, (z + dev_z)/2 + 2],
     [dev_x - 6, dev_y(k) + sy, dev_z + 1], [dev_x - 1, dev_y(k) + sy, dev_z]];

mot_c = [motor_x0 + (motor_d + 0.4)/2, 0.2 + motor_t/2, 0.05 + motor_d/2];   // motor in its pocket
function motor_in_path(s) =
    let (x = mot_c[0] + (s == 0 ? -0.8 : 0.8), z = s == 0 ? H_in - 3.6 : H_in - 2.2,
         xj = hx(lead_row[1]), yj = hy(lead_col[1][s]))
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
P("keepout") {
    box(px0, px0 + perf[0], hy(8) - 1.3, py0 + perf[1], zs - 3, zs - 0.01);
    box(px0, px0 + perf[0], hy(18) - 1.3, hy(17) + 1.3, zs - 3, zs - 0.01);
}
