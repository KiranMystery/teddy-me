// teddy-me electronics box: printable body + lid.
//
//   openscad -D 'part="body"' -o stl/teddy-box-body.stl enclosure.scad
//   openscad -D 'part="lid"'  -o stl/teddy-box-lid.stl  enclosure.scad
//   (or just run ./build.sh)
//
// Coordinates used everywhere in this file and in assembly.scad:
//   origin = inside corner of the box floor
//   x = 0  inner face of the PORT wall (both USB sockets and the switch)
//   y = 0  inner face of the wall beside the ESP32 (the "gutter" wall)
//   z = 0  top of the floor
//   +x is the antenna end, +y is the battery side, +z is the lid.

// =====================================================================
//  PARAMETERS  -  everything that depends on a real part lives here.
//  "MEASURE" = not verified, put calipers on your part before printing.
// =====================================================================

/* [What to build] */
board = "38pin";        // "38pin" (Ellie, DevKitC) or "30pin" (Bruno, DevKit V1)
power = "battery";      // "battery": LiPo + charger board + switch inside the box
                        // "usb":     no battery. A power bank plugs into the
                        //            ESP32's own USB socket (prototype build)
part  = "body";         // "body", "lid" (both in print orientation) or "none"
motor_in_box = false;   // true: coin motor sits in the pocket inside the box,
                        //       so only two leads (LED, paw) leave the box

/* [Print and shell] */
wall     = 2.4;         // side walls
floor_t  = 2.0;         // floor
lid_t    = 3.0;         // lid plate (thick enough for the countersinks)
tol      = 0.3;         // print tolerance: clearance left around every part
corner_r = 5.0;         // radius of the four vertical outside corners
edge_r   = 2.0;         // rounding of the top and bottom outside edges
inner_r  = 1.0;         // inside corner radius of the cavity

/* [Lid screws] */
// Default: 4x M3 x 10 countersunk screws driven straight into 2.5 mm pilot
// holes (thread-forming). Set lid_insert = true for M3 heat-set inserts.
lid_insert      = false;
lid_pilot_d     = 2.5;  // pilot hole for an M3 screw cutting its own thread
lid_insert_d    = 4.0;  // hole for an M3 heat-set insert (4.6 mm OD type)
lid_insert_len  = 6.0;  // insert length + 0.5
lid_screw_len   = 10;   // screw length under the head top
lid_clear_d     = 3.4;  // M3 clearance hole in the lid
lid_head_d      = 6.0;  // countersunk head diameter (DIN 965 = 5.6, DIN 7991 = 6.0)
boss_off        = 2.4;  // screw axis distance from the two inner wall faces

/* [Small screws: carrier and charger board] */
// M2 x 5 pan-head self-tapping screws into 1.7 mm pilot holes.
m2_pilot_d = 1.7;

/* [Carrier perfboard]  MEASURE */
perf            = [70, 50, 1.6]; // length (x), width (y), thickness
perf_hole_inset = 2.0;  // corner mounting holes: centre distance from each edge
perf_grid_x0    = 5.79; // first hole centre from a SHORT edge (24 holes on 70 mm)
perf_grid_y0    = 3.41; // first hole centre from a LONG edge  (18 holes on 50 mm)
perf_standoff_h = 15;   // underside of the perfboard above the floor.
                        // The charger board and switch live in this space.
perf_standoff_usb = 5;  // the same for power = "usb": only the carrier's own
                        // solder joints and links (3 mm) are under the board
perf_post       = 4.4;  // size of the square corner posts under the board
                        // (kept small: the first solder joints are 5.8 mm in)

/* [ESP32 dev board]  MEASURE */
//        overall L, PCB L, width, row-to-row, pins/side, first pin from the USB end
esp_38 = [54.3,     48.26, 27.94, 25.4,       19,        1.27];
esp_30 = [51.5,     51.5,  28.3,  25.4,       15,        8.0 ];
esp_usb_type     = "micro"; // "micro" or "c"   (socket on the dev board)
esp_usb_overhang = 1.0;  // how far the USB socket sticks out past the PCB end
// Where the ESP32 sits on the carrier (carrier-38pin.svg / carrier-30pin.svg):
// its USB-end pin is in the LAST hole row (row 24) and its two pin rows are in
// hole columns 8 and 18. On a real perfboard the last hole row is ~5.8 mm in
// from the edge, so the 38-pin board ends ~4.5 mm inside the perfboard edge
// and the 30-pin board overhangs it by ~2.2 mm. Both are handled below.
esp_last_pin_x   = perf_grid_x0;              // USB-end pin, from the port edge
esp_center_y     = perf_grid_y0 + 5*2.54;     // centre line, from the gutter edge
header_h      = 8.5;     // female header height above the perfboard
pin_spacer_h  = 2.5;     // black plastic strip on the ESP32's own pins
esp_pcb_t     = 1.6;     // ESP32 board thickness
esp_top_h     = 3.4;     // tallest part on top of the ESP32 (shield can)
esp_usb_h_micro = 1.3;   // socket centre above the ESP32 PCB top, micro-USB
esp_usb_h_c     = 1.7;   // same for USB-C

/* [USB plug cut-outs] */
// Sized for the plug's moulded body so it can seat fully: [width, height]
// (USB spec maximum plug body: micro-B 10.6 x 8.5, USB-C 12.35 x 6.5)
cut_micro = [12.4, 9.4];
cut_c     = [13.6, 7.8];
cut_r     = 1.2;         // corner radius of the cut-outs

/* [Charger: Adafruit bq25185 USB-C charger + 5 V boost, product 6106] */
// Outline, holes, socket and pad positions are from Adafruit's Eagle board
// file. Board frame: USB-C on the short edge at x = 0, header pads along
// y = 2.54, JST battery socket opening on the far long edge, 5 V screw
// terminal at the other short edge. Heights are NOT in the file: MEASURE.
chg       = [29.21, 19.05, 1.6];  // length, width, thickness (thickness MEASURE)
chg_holes = [[2.54, 2.54], [2.54, 16.51], [26.67, 2.54], [26.67, 16.51]]; // 2.5 mm
chg_usb_cy       = 9.525;  // USB-C centre across the board
chg_usb_overhang = 1.14;   // socket mouth past the board edge
chg_usb_h        = 1.65;   // socket centre above the PCB top           MEASURE
chg_standoff_h   = 2.5;    // underside of the charger above the floor
chg_standoff_r   = 2.1;    // small, so it clears the EN and VIN pad joints
chg_top_h        = 9.0;    // tallest part: the 3.5 mm screw terminal   MEASURE
chg_jst   = [9.97, 10.994, 8.0, 7.5];  // battery socket: x, y, length, depth
chg_term  = [22.0, 6.125, 7.0, 7.0];   // screw terminal body: x, y, length, width
chg_term_pads = [[25.4, 7.825], [25.4, 11.325]];   // +5V, GND
chg_pad_y = 2.54;                      // header pad row
chg_pad_x = [5.715, 8.255, 10.795, 13.335, 15.875, 18.415, 20.955, 23.495];
//           VIN    VBUS   D-      D+      G       BAT     5V      EN

/* [Battery]  MEASURE */
batt = [60, 36, 7];      // length, width, thickness (stands on its long edge)
batt_len_clear = 2.0;    // spare length
batt_lead_room = 4.5;    // room for the lead to bend at the port end
batt_t_clear   = 1.5;    // spare thickness (swelling + a strip of foam)
batt_h_clear   = 1.5;    // spare height under the lid
div_t          = 1.6;    // wall between battery and electronics

/* [Slide switch SS12D00]  MEASURE */
sw_body      = [8.5, 3.5, 3.5]; // length (slide direction), width, height
sw_lever_len = 4.0;      // lever length above the body (G4 = 4, G3 = 3)
sw_lever_w   = 1.5;      // lever is square in section
sw_travel    = 2.0;      // lever travel
sw_recess    = [18, 10]; // finger recess in the outside wall: width, height
sw_zc        = 7.0;      // switch centre above the floor

/* [Leads leaving the box] */
n_leads     = 3;         // motor, LED, paw button (2 when motor_in_box)
wire_d      = 1.4;       // outside diameter of ONE wire of a 2-wire lead MEASURE
lead_squeeze= 0.2;       // how much the lid pinches the two stacked wires
exit_pitch  = 6.0;       // spacing between lead exits
fence_t     = 1.6;       // inner strain-relief fence
jog         = 3.5;       // sideways step between fence slot and wall slot

/* [USB cable tie, power = "usb" only] */
// Two slots through the long wall beside the ESP32. A cable tie goes in one,
// out the other and round the power cable, which loops back from the plug
// and lies along that wall, so a tug on the cable never reaches the socket.
cable_tie = true;
tie_slot  = [4.6, 1.9];  // slot for a 3.6 mm wide tie: length along the wall, height
tie_x     = 46.5;        // start of the slots along the wall (clear of the lid fins)
tie_rise  = [3.0, 10.0]; // bottom of each slot above the top of the carrier
cable_d   = 3.5;         // power cable diameter, only used by assembly.scad

/* [Coin vibration motor pocket]  MEASURE */
motor_pocket = true;
motor_d  = 10.0;
motor_t  = 3.0;
motor_x0 = 12;           // pocket position along the gutter wall

/* [Lid] */
rim_h    = 2.5;          // locating rim under the lid
rim_t    = 1.6;
rim_gap  = 0.25;
holddown = true;         // fins under the lid that keep the carrier on its posts
holddown_gap = 0.2;      // air between a fin and the perfboard
// fins as [x from, x to] along the carrier, in the bare strip along each long
// edge (clear of the parts in both carrier drawings)
hd_batt_side   = [[38, 46]];     // thin fin on the battery-side edge
hd_batt_post   = [9.6, 12.4];    // small post on the battery-side edge
hd_gutter_side = [[34, 42], [56, 64]];
top_clear = 1.0;         // air above the ESP32 below the rim
labels   = true;         // deboss PROG / CHARGE next to the USB cut-outs

// =====================================================================
//  DERIVED VALUES  (no need to edit)
// =====================================================================
$fn = 48;
ov  = 0.2;               // overlap so that features fuse with walls and floor

usb          = power == "usb";
esp          = board == "30pin" ? esp_30 : esp_38;
esp_len      = esp[0];
esp_pcb_len  = esp[1];
esp_w        = esp[2];
esp_rows     = esp[3];
esp_pins     = esp[4];
esp_pin1     = esp[5];
esp_cut      = esp_usb_type == "c" ? cut_c : cut_micro;
esp_usb_h    = esp_usb_type == "c" ? esp_usb_h_c : esp_usb_h_micro;
esp_stack    = header_h + pin_spacer_h + esp_pcb_t + esp_top_h;

boss_r  = lid_insert ? lid_insert_d/2 + 1.6 : lid_pilot_d/2 + 1.4;
blk     = boss_off + boss_r;       // corner taken by a lid screw boss
gutter  = blk;                     // strip between the gutter wall and the carrier

esp_x0r = esp_last_pin_x - esp_pin1; // ESP32 PCB end relative to the perfboard's
                                   // port edge (+ inside, - overhanging)
px0     = tol + max(0, esp_usb_overhang - esp_x0r); // perfboard port edge
bay_y0  = gutter;
py0     = bay_y0 + tol;            // perfboard: nominal position of its gutter edge
div_y0  = bay_y0 + perf[1] + 2*tol;
batt_y0 = div_y0 + div_t;
batt_slot = batt[2] + batt_t_clear;
// power = "usb": no battery slot. The far side gets a strip like the gutter,
// just wide enough for the two lid screw bosses.
W_in    = usb ? div_y0 + gutter : batt_y0 + batt_slot;

fence_x0 = px0 + perf[0] + tol;
L_in    = usb ? fence_x0 + fence_t + jog
              : max(fence_x0 + fence_t + jog,
                    2*blk + batt[0] + batt_len_clear + batt_lead_room);

zs      = usb ? perf_standoff_usb : perf_standoff_h;   // perfboard underside
zt      = zs + perf[2];            // perfboard top
// power = "usb": the box is only as tall as the ESP32 needs. The lid rim on
// the port wall must also stay 0.3 mm above the USB cut-out, which a full-size
// plug body fills.
H_in    = usb ? max(zt + esp_stack + top_clear + rim_h,
                    zt + header_h + pin_spacer_h + esp_pcb_t + esp_usb_h
                       + esp_cut[1]/2 + 0.3 + rim_h)
              : max(batt[1] + batt_h_clear, zt + esp_stack + top_clear + rim_h);
tie_z   = [zt + tie_rise[0], zt + tie_rise[1]];        // bottoms of the two tie slots

n_exits  = motor_in_box ? n_leads - 1 : n_leads;
fence_len= (n_exits - 1)*exit_pitch + 3 + jog + 3.5;
fence_y0 = div_y0 - fence_len;
notch_w  = wire_d + 0.3;
notch_d  = 2*wire_d - lead_squeeze;
function fence_notch_y(i) = fence_y0 + 3 + i*exit_pitch;
function wall_notch_y(i)  = fence_notch_y(i) + jog;

// USB socket centres on the port wall
esp_mouth_x = px0 + esp_x0r - esp_usb_overhang;   // ESP32 USB socket mouth (>= tol)
ue_y = py0 + esp_center_y;
ue_z = zt + header_h + pin_spacer_h + esp_pcb_t + esp_usb_h;
chg_x0 = chg_usb_overhang + 0.2;   // socket mouth 0.2 mm short of the wall
chg_y0 = bay_y0 + perf_post + 1.0;
chg_z  = chg_standoff_h;
up_y  = chg_y0 + chg_usb_cy;
up_z  = chg_z + chg[2] + chg_usb_h;

// switch
sw_web   = 1.2;                                // plastic between switch and recess
sw_rdepth= sw_lever_len - sw_web + 0.2;        // recess depth: lever ends 0.2 below the surface
sw_x     = -wall + sw_rdepth + sw_web;         // front face of the switch body
sw_yc    = div_y0 - sw_recess[0]/2 - 0.6;
sw_top   = sw_zc + sw_body[1]/2 + 0.2;

// battery lead window in the divider
win_x0 = blk + 0.6;
win    = [12, 9];                              // x size, z size
win_z0 = 3;

// lid screw axes
boss_xy = [[boss_off, boss_off], [L_in - boss_off, boss_off],
           [boss_off, W_in - boss_off], [L_in - boss_off, W_in - boss_off]];
// perfboard corner holes
perf_hole_xy = [for (ix = [0, 1], iy = [0, 1])
    [px0 + (ix ? perf[0] - perf_hole_inset : perf_hole_inset),
     py0 + (iy ? perf[1] - perf_hole_inset : perf_hole_inset)]];

L_out = L_in + 2*wall;  W_out = W_in + 2*wall;  H_out = floor_t + H_in + lid_t;

// The charger sits under the ESP32, between the two header rows, where the
// carrier has no solder joints or links. Its screw terminal still needs air.
assert(usb || perf_standoff_h >= chg_standoff_h + chg[2] + chg_top_h + 0.8,
       "perf_standoff_h too low: the charger's screw terminal would touch the carrier");
assert(usb || sw_zc + sw_recess[1]/2 + 1.2 <= zs - 0.5, "switch recess reaches the perfboard");
assert(!usb || perf_standoff_usb >= 4, "perf_standoff_usb too low for the carrier's solder joints");
assert(!usb || !cable_tie || tie_z[1] + tie_slot[1] + 1.5 <= H_in - rim_h, "tie slot reaches the lid rim");
assert(motor_t + 0.4 + 1.2 <= gutter, "motor pocket does not fit in the gutter");
assert(corner_r >= edge_r);
if (part != "none")
    echo(str("OUTSIDE SIZE  ", L_out, " x ", W_out, " x ", H_out, " mm;  inside ",
             L_in, " x ", W_in, " x ", H_in));

// =====================================================================
//  HELPERS
// =====================================================================
module rrect(x0, y0, x1, y1, r) {
    hull() for (x = [x0 + r, x1 - r], y = [y0 + r, y1 - r])
        translate([x, y]) circle(r);
}
module box(x0, x1, y0, y1, z0, z1) {
    translate([x0, y0, z0]) cube([x1 - x0, y1 - y0, z1 - z0]);
}
// rounded rectangle in the y-z plane, extruded along x from x0 to x1
module yz_slot(x0, x1, yc, zc, w, h, r) {
    translate([x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(x1 - x0)
        rrect(yc - w/2, zc - h/2, yc + w/2, zc + h/2, r);
}
// same, with the outside edge flared by `fl` so there is no sharp rim
module yz_cut(yc, zc, w, h, r, x_in, fl = 0.7) {
    yz_slot(-wall - 1, x_in, yc, zc, w, h, r);
    hull() {
        yz_slot(-wall - 0.01, -wall, yc, zc, w + 2*fl, h + 2*fl, r + fl);
        yz_slot(-wall + fl, -wall + fl + 0.01, yc, zc, w, h, r);
    }
}

// Outside shape. One edge (z_round) gets a fillet whose lowest 45 degrees are
// replaced by a straight chamfer, so it prints on the bed without supports;
// the other edge (the lid seam) gets a 0.4 mm chamfer.
module shell(z_round, z_seam) {
    s  = z_seam > z_round ? 1 : -1;
    re = edge_r; rc = corner_r; c = 0.4;
    prof = concat(
        [[0, 0], [rc - 0.586*re, 0]],
        [for (a = [-45 : 7.5 : 0]) [rc - re + re*cos(a), re + re*sin(a)]],
        [[rc, abs(z_seam - z_round) - c], [rc - c, abs(z_seam - z_round)],
         [0, abs(z_seam - z_round)]]);
    hull() for (x = [-wall + rc, L_in + wall - rc], y = [-wall + rc, W_in + wall - rc])
        translate([x, y, z_round]) scale([1, 1, s])
            rotate_extrude($fn = 64) polygon(prof);
}
module cavity() {
    translate([0, 0, 0]) linear_extrude(H_in + 10) rrect(0, 0, L_in, W_in, inner_r);
}

// =====================================================================
//  BODY
// =====================================================================
module lid_bosses() {
    // gutter-side corners: round columns fused into the corner
    for (b = [boss_xy[0], boss_xy[1]]) {
        sx = b[0] < L_in/2 ? -1 : 1;
        hull() {
            translate([b[0], b[1], -ov]) cylinder(r = boss_r, h = H_in + ov);
            translate([b[0] + sx*(boss_off + ov)/2, (boss_off - ov)/2 - ov/2, -ov + (H_in + ov)/2])
                cube([boss_off + ov, boss_off + ov, H_in + ov], center = true);
        }
    }
    if (usb) {
        // far-side corners: the same round columns, mirrored
        for (b = [boss_xy[2], boss_xy[3]]) {
            sx = b[0] < L_in/2 ? -1 : 1;
            hull() {
                translate([b[0], b[1], -ov]) cylinder(r = boss_r, h = H_in + ov);
                translate([b[0] + sx*(boss_off + ov)/2, W_in - (boss_off - ov)/2 + ov/2, -ov + (H_in + ov)/2])
                    cube([boss_off + ov, boss_off + ov, H_in + ov], center = true);
            }
        }
    } else {
        // battery-side corners: solid end blocks, so the battery only ever
        // touches flat walls
        box(-ov, blk, batt_y0 - ov, W_in + ov, -ov, H_in);
        box(L_in - blk, L_in + ov, batt_y0 - ov, W_in + ov, -ov, H_in);
    }
}

module divider() {
    box(-ov, L_in + ov, div_y0, batt_y0, -ov, H_in);
}

module perf_posts() {
    p = perf_post; lip = 1.2;
    x1 = px0 + perf[0];
    // port end, gutter side
    box(-ov, px0 + p, bay_y0 - lip, py0 + p, -ov, zs);
    box(-ov, px0 + p, bay_y0 - lip, bay_y0, -ov, zt);
    // port end, battery side (the divider is its fence)
    box(-ov, px0 + p, div_y0 - tol - p, div_y0 + ov, -ov, zs);
    if (usb) {   // no divider: the far edge gets its own lips, like the gutter side
        box(-ov, px0 + p, div_y0, div_y0 + lip, -ov, zt);
        box(x1 - p, fence_x0 + lip, div_y0, div_y0 + lip, -ov, zt);
    }
    // antenna end, gutter side
    box(x1 - p, fence_x0 + lip, bay_y0 - lip, py0 + p, -ov, zs);
    box(x1 - p, fence_x0 + lip, bay_y0 - lip, bay_y0, -ov, zt);
    box(fence_x0, fence_x0 + lip, bay_y0 - lip, py0 + p, -ov, zt);
    // antenna end, battery side (the strain-relief fence is its fence)
    box(x1 - p, fence_x0 + ov, div_y0 - tol - p, div_y0 + ov, -ov, zs);
}

module chg_mount() {
    // four screw standoffs, one under each mounting hole
    for (h = chg_holes) translate([chg_x0 + h[0], chg_y0 + h[1], -ov])
        cylinder(r = chg_standoff_r, h = chg_z + ov, $fn = 32);
}

module switch_block() {
    rw = sw_recess[0]; rh = sw_recess[1];
    // thick pad behind the finger recess
    box(-ov, sw_x, sw_yc - rw/2 - 1.2, sw_yc + rw/2 + 1.2, -ov, sw_zc + rh/2 + 1.2);
    // cradle the switch drops into from above
    box(sw_x - ov, sw_x + sw_body[2] + 0.2 + 1.5,
        sw_yc - sw_body[0]/2 - 1.6, sw_yc + sw_body[0]/2 + 1.6, -ov, sw_top);
}
module switch_cuts() {
    rw = sw_recess[0]; rh = sw_recess[1];
    // finger recess from outside
    yz_cut(sw_yc, sw_zc, rw, rh, 2.5, sw_x - sw_web);
    // slot for the lever
    yz_slot(sw_x - sw_web - ov, sw_x + ov, sw_yc, sw_zc,
            sw_travel + sw_lever_w + 1.0, sw_lever_w + 0.7, 0.4);
    // the same slot carried up to the top of the pad on the battery side, so the
    // switch can be lowered in with its lever already poking outwards
    box(sw_x - sw_web - ov, sw_x + ov, sw_yc + sw_travel/2 - (sw_lever_w + 0.7)/2,
        sw_yc + sw_travel/2 + (sw_lever_w + 0.7)/2, sw_zc, sw_zc + sw_recess[1]/2 + 2.2);
    // pocket for the body, open at the top
    box(sw_x, sw_x + sw_body[2] + 0.2, sw_yc - sw_body[0]/2 - 0.15,
        sw_yc + sw_body[0]/2 + 0.15, sw_zc - sw_body[1]/2 - 0.15, sw_top + 1);
    // gap for the three pins and their wires
    box(sw_x + sw_body[2], sw_x + sw_body[2] + 3, sw_yc - sw_body[0]/2 + 1.5,
        sw_yc + sw_body[0]/2 - 1.5, sw_zc - sw_body[1]/2 - 0.15, sw_top + 1);
}

module motor_pocket_walls() {
    mt = motor_t + 0.4; mw = motor_d + 0.4; lip = 1.2; h = motor_d*0.7;
    box(motor_x0 - lip, motor_x0 + mw + lip, mt, mt + lip, -ov, h);
    box(motor_x0 - lip, motor_x0, -ov, mt, -ov, h);
    box(motor_x0 + mw, motor_x0 + mw + lip, -ov, mt, -ov, h);
}

module strain_fence() {
    box(fence_x0, fence_x0 + fence_t, fence_y0, (usb ? W_in : div_y0) + ov, -ov, H_in);
    box(fence_x0, L_in + ov, fence_y0, fence_y0 + fence_t, -ov, H_in);
}
module lead_notch(x0, x1, y, flare = false) {
    zb = H_in - notch_d + notch_w/2;
    hull() {
        translate([x0, y, zb]) rotate([0, 90, 0]) cylinder(d = notch_w, h = x1 - x0, $fn = 24);
        box(x0, x1, y - notch_w/2, y + notch_w/2, H_in, H_in + 1);
    }
    if (flare) hull() {     // soften the outside edge of the wall slot
        translate([x1 - 0.8, y, zb]) rotate([0, 90, 0]) cylinder(d = notch_w, h = 0.01, $fn = 24);
        translate([x1 - 0.8, y - notch_w/2, H_in]) cube([0.01, notch_w, 1]);
        translate([x1, y, zb]) rotate([0, 90, 0]) cylinder(d = notch_w + 1.4, h = 0.01, $fn = 24);
        translate([x1, y - notch_w/2 - 0.7, H_in]) cube([0.01, notch_w + 1.4, 1]);
    }
}

module port_label(txt, yc, zc, size = 3.6) {
    translate([-wall + 0.45, yc, zc]) rotate([0, 0, -90]) rotate([90, 0, 0])
        linear_extrude(1) text(txt, size = size, halign = "center", valign = "center",
                               font = "Liberation Sans:style=Bold");
}

module body() {
    difference() {
        union() {
            difference() { shell(-floor_t, H_in); cavity(); }
            lid_bosses();
            perf_posts();
            if (!usb) {
                divider();
                chg_mount();
                switch_block();
            }
            if (motor_pocket) motor_pocket_walls();
            strain_fence();
        }
        // --- openings in the port wall ---
        yz_cut(ue_y, ue_z, esp_cut[0], esp_cut[1], cut_r, 0.5);      // ESP32 USB
        if (!usb) {
            yz_cut(up_y, up_z, cut_c[0], cut_c[1], cut_r, 0.5);      // charging USB-C
            switch_cuts();
        }
        if (labels) {
            port_label(usb ? "USB 5V" : "PROG", ue_y, ue_z - esp_cut[1]/2 - 3.6);
            if (!usb) port_label("CHARGE", up_y, up_z + cut_c[1]/2 + 3.6);
        }
        // --- cable tie slots in the gutter wall (power = "usb") ---
        if (usb && cable_tie) for (z = tie_z)
            box(tie_x, tie_x + tie_slot[0], -wall - 1, 0.5, z, z + tie_slot[1]);
        // --- lead exits: slot in the fence, offset slot in the wall ---
        for (i = [0 : n_exits - 1]) {
            lead_notch(fence_x0 - ov, fence_x0 + fence_t + ov, fence_notch_y(i));
            lead_notch(L_in - ov, L_in + wall + ov, wall_notch_y(i), flare = true);
        }
        // --- battery lead window in the divider ---
        if (!usb) translate([0, div_y0 - ov, 0]) rotate([90, 0, 0]) mirror([0, 0, 1])
            linear_extrude(div_t + 2*ov)
                rrect(win_x0, win_z0, win_x0 + win[0], win_z0 + win[1], 2);
        // --- screw holes ---
        for (b = boss_xy) {
            if (lid_insert) translate([b[0], b[1], H_in - lid_insert_len])
                cylinder(d = lid_insert_d, h = lid_insert_len + 1, $fn = 32);
            translate([b[0], b[1], H_in - (lid_screw_len - lid_t) - 2])
                cylinder(d = lid_pilot_d, h = lid_screw_len, $fn = 32);
            translate([b[0], b[1], H_in - 0.5])
                cylinder(d1 = lid_insert ? lid_insert_d : lid_pilot_d,
                         d2 = (lid_insert ? lid_insert_d : lid_pilot_d) + 1.2, h = 0.6, $fn = 32);
        }
        // (never deeper than 0.8 mm short of the outside of the floor)
        for (h = perf_hole_xy) translate([h[0], h[1], max(zs - 7, 0.8 - floor_t)])
            cylinder(d = m2_pilot_d, h = zs + 1 - max(zs - 7, 0.8 - floor_t), $fn = 24);
        if (!usb) for (h = chg_holes) translate([chg_x0 + h[0], chg_y0 + h[1], -1.3])
            cylinder(d = m2_pilot_d, h = chg_z + 2.3, $fn = 24);
    }
}

// =====================================================================
//  LID
// =====================================================================
module rim_bar(x0, x1, y0, y1) {
    // bar hanging under the lid, lower edges chamfered as a lead-in
    hull() {
        box(x0, x1, y0, y1, H_in - rim_h + 0.8, H_in + ov);
        box(x0 + 0.5, x1 - 0.5, y0 + 0.5, y1 - 0.5, H_in - rim_h, H_in);
    }
}
// Fins that reach down to just above the carrier. Each presses on the bare
// 2 mm strip along a long edge and is thicker at the root for stiffness.
module fin(x0, x1, y_tip0, y_tip1, y_root0, y_root1) {
    zb = zt + holddown_gap;
    hull() {
        box(px0 + x0, px0 + x1, y_tip0, y_tip1, zb, zb + 1);
        box(px0 + x0, px0 + x1, y_root0, y_root1, H_in - 0.5, H_in + ov);
    }
}
module holddown_fins() {
    yb = py0 + perf[1];                        // battery-side edge of the carrier
    for (f = hd_batt_side) fin(f[0], f[1], yb - 1.8, yb - 0.2, yb - 4.6, yb - 0.2);
    fin(hd_batt_post[0], hd_batt_post[1], yb - 5.0, yb - 0.2, yb - 6.5, yb - 0.2);
    for (f = hd_gutter_side) fin(f[0], f[1], py0 + 0.2, py0 + 1.4, py0 - 2.2, py0 + 1.4);
}
module lid() {
    g = rim_gap;
    difference() {
        union() {
            shell(H_in + lid_t, H_in);
            rim_bar(g, g + rim_t, blk + 0.6, (usb ? W_in - blk : div_y0) - 0.6);   // port wall
            if (usb) rim_bar(blk + 0.6, min(L_in - blk, fence_x0) - 0.6,
                             W_in - g - rim_t, W_in - g);                  // far wall
            rim_bar(blk + 0.6, L_in - blk - 0.6, g, g + rim_t);             // gutter wall
            rim_bar(L_in - g - rim_t, L_in - g, blk + 0.6, fence_y0 - 0.6); // antenna wall
            if (holddown) holddown_fins();
        }
        for (b = boss_xy) {
            translate([b[0], b[1], H_in - 1]) cylinder(d = lid_clear_d, h = lid_t + 2, $fn = 32);
            cs = (lid_head_d + 0.4 - lid_clear_d)/2;   // 90 degree countersink
            translate([b[0], b[1], H_in + lid_t - cs])
                cylinder(d1 = lid_clear_d, d2 = lid_head_d + 0.4, h = cs + 0.01, $fn = 32);
        }
    }
}

// =====================================================================
//  OUTPUT (print orientation: both parts flat on the bed, no supports)
// =====================================================================
if (part == "body") translate([wall, wall, floor_t]) body();
if (part == "lid")  translate([wall, W_in + wall, H_in + lid_t]) rotate([180, 0, 0]) lid();
