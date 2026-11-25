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
carrier = "full";       // "full":    the 5 x 7 cm perfboard as bought (carrier-*.svg)
                        // "compact": perfboard cut to 14 columns, small parts under
                        //            the ESP32 (carrier-compact-*.svg). Needs power = "usb"
                        // "14x20":   the 4 x 6 cm perfboard with 14 x 20 holes, uncut. A 30-pin
                        //            USB-C ESP32 is soldered straight onto it and the small parts
                        //            hang under it (carrier-14x20.svg). Needs power = "usb";
                        //            `board` is ignored
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
cut_tol         = 0.4;  // carrier = "compact": clearance round the board you cut
                        // yourself. It is 14 holes wide and (pins + 2) holes long,
                        // cut along the next row of holes, so every edge is half a
                        // hole pitch (1.27 mm) outside the last holes
                        // (kept small: the first solder joints are 5.8 mm in)

/* [Carrier perfboard for carrier = "14x20"]  MEASURE */
// The common 4 x 6 cm board with 14 x 20 holes, used uncut. Its corner holes
// are taken to be perf_hole_inset in from each edge, like the 5 x 7 cm board.
perf14         = [60, 40, 1.6]; // length (x), width (y), thickness
perf14_grid_x0 = 5.87;  // first hole centre from a SHORT edge (20 holes on 60 mm)
perf14_grid_y0 = 3.49;  // first hole centre from a LONG edge  (14 holes on 40 mm)
perf14_standoff = 8.0;  // underside of this board above the floor. The small parts hang
                        // under it: the capacitor lying flat needs 7.5 mm
// The ESP32 that goes on it, soldered straight to the board with no socket
// strips: 30 pins, USB-C, a mounting hole in each corner. Taken from a photo
// of the board beside a ruler, so good to about 0.5 mm.
//        overall L, PCB L, width, row-to-row, pins/side, first pin from the USB end
esp_14         = [51.8, 51.8, 28.5, 25.4, 15, 9.2];
usb14_overhang = 2.2;   // its USB-C socket sticks out this far past the PCB end
usb14_spare    = 3;     // empty hole rows between the port edge and the row of the VIN pin
top14          = 13.4;  // room above the board: a plugged JST-XH connector (10.5 mm)
                        // and its two wires bending over above it
wire14_d       = 1.7;   // one wire of a lead: 22 AWG silicone
tie14_rise     = [2.0, 7.4];            // cable tie slots above the board (see tie_rise)
hd14_gutter    = [[30, 36], [48, 54]];  // lid fins on the board's edge beside the ESP32, as
                                        // [x from, x to] from the board's port edge
hd14_far       = [[44, 50]];            // lid fin on the connector-side edge, beyond MOTOR
tie14_x        = 12;    // cable tie slots, from the board's port edge. Nearer the
                        // port than every fin, so the lid can swing shut past the tie
// This box has no strip either side of the board for lid screws. The port end
// of the lid tucks under a lip on the body instead, and two screws at the
// antenna end hold it down.
tuck_reach     = 2.0;   // how far the lip reaches over the lid
tuck_gap       = 0.2;   // air between the lip and the lid
tuck_toe       = 0.3;   // the lip starts this far inside the port wall's inner face

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
// (compact: one spare row beyond the USB-end pin, pin rows in columns 3 and 13 of 14)
// (14x20: USB-end pin in the last hole row, row 20, pin rows in columns 3 and 13 of 14)
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
b14          = carrier == "14x20";       // the uncut 14 x 20 hole board
esp          = b14 ? esp_14 : board == "30pin" ? esp_30 : esp_38;
p30          = b14 || board == "30pin";  // 30-pin pin order
usb_c        = b14 || esp_usb_type == "c";
hdr_h        = b14 ? 0 : header_h;       // 14x20: no socket strips under the ESP32
usb_ov       = b14 ? usb14_overhang : esp_usb_overhang;
lead_d       = b14 ? wire14_d : wire_d;  // one wire of a lead
esp_len      = esp[0];
esp_pcb_len  = esp[1];
esp_w        = esp[2];
esp_rows     = esp[3];
esp_pins     = esp[4];
esp_pin1     = esp[5];
esp_cut      = usb_c ? cut_c : cut_micro;
esp_usb_h    = usb_c ? esp_usb_h_c : esp_usb_h_micro;
esp_stack    = hdr_h + pin_spacer_h + esp_pcb_t + esp_top_h;

compact = carrier == "compact";
assert(!compact || usb, "carrier = \"compact\" has no room for the charger: use power = \"usb\"");
tuck    = b14;                           // lid tucks under a lip at the port end: two lid screws
lay14   = compact || b14;                // 14 columns: the small parts sit under the ESP32
assert(!b14 || usb, "carrier = \"14x20\" has no room for the charger: use power = \"usb\"");
n_rows  = compact ? esp_pins + 2 : b14 ? 20 : 24;   // hole rows along the board, row n_rows at the USB end
n_cols  = lay14 ? 14 : 18;                   // hole columns across it, column n_cols at the gutter side
pf      = compact ? [n_rows*2.54, n_cols*2.54, perf[2]] : b14 ? perf14 : perf;   // the board actually fitted
gx0     = compact ? 1.27 : b14 ? perf14_grid_x0 : perf_grid_x0;   // first hole from a short edge
gy0     = compact ? 1.27 : b14 ? perf14_grid_y0 : perf_grid_y0;   // first hole from a long edge
ptol    = compact ? cut_tol : tol;           // clearance round the board
usb_spare = compact ? 1 : b14 ? usb14_spare : 0;   // empty rows beyond the USB-end pin
esp_last_pin_x = gx0 + usb_spare*2.54;       // USB-end pin, from the board's port edge
// (compact: pin rows in columns 3 and 13.  14x20: columns 4 and 14, which the board labels K and A)
esp_center_y   = (lay14 && !b14) ? gy0 + 6*2.54 : gy0 + 5*2.54;   // ESP32 centre line, from the gutter edge
row25   = (n_rows - usb_spare - esp_pins + 1) + (p30 ? 7 : 8);  // hole row of GPIO 25
function row_x(r) = px0 + gx0 + (n_rows - r)*2.54;        // x of hole row r

boss_r  = lid_insert ? lid_insert_d/2 + 1.6 : lid_pilot_d/2 + 1.4;
blk     = boss_off + boss_r;       // corner taken by a lid screw boss
gutter  = tuck ? 0 : blk;          // strip between the gutter wall and the carrier

esp_x0r = esp_last_pin_x - esp_pin1; // ESP32 PCB end relative to the perfboard's
                                   // port edge (+ inside, - overhanging)
px0     = max(ptol, tol + usb_ov - esp_x0r); // perfboard port edge
bay_y0  = gutter;
py0     = bay_y0 + ptol;           // perfboard: nominal position of its gutter edge
div_y0  = bay_y0 + pf[1] + 2*ptol;
batt_y0 = div_y0 + div_t;
batt_slot = batt[2] + batt_t_clear;
// power = "usb": no battery slot. The far side gets a strip like the gutter,
// just wide enough for the two lid screw bosses.
W_in    = usb ? div_y0 + gutter : batt_y0 + batt_slot;

// the strain-relief fence stands beyond the board, and beyond the ESP32 where
// that overhangs the board (it does on the compact carrier)
fence_x0 = max(px0 + pf[0] + ptol, px0 + esp_x0r + esp_len + 0.5);
L_in    = usb ? fence_x0 + fence_t + jog
              : max(fence_x0 + fence_t + jog,
                    2*blk + batt[0] + batt_len_clear + batt_lead_room);

zs      = b14 ? perf14_standoff : usb ? perf_standoff_usb : perf_standoff_h;   // perfboard underside
zt      = zs + pf[2];              // perfboard top
// power = "usb": the box is only as tall as the ESP32 needs. The lid rim on
// the port wall must also stay 0.3 mm above the USB cut-out, which a full-size
// plug body fills.
// tuck: there is no lid rim on the port wall, and that wall carries on up
// beside the lid, so the cut-out may reach to 0.3 mm below the lid.
H_in0   = b14 ? max(zt + top14, zt + pin_spacer_h + esp_pcb_t + esp_usb_h + esp_cut[1]/2 + 0.3)
        : usb ? max(zt + esp_stack + top_clear + rim_h,
                    zt + header_h + pin_spacer_h + esp_pcb_t + esp_usb_h
                       + esp_cut[1]/2 + 0.3 + (tuck ? 0 : rim_h))
              : max(batt[1] + batt_h_clear, zt + esp_stack + top_clear + rim_h);
H_in    = tuck ? ceil(2*H_in0 - 0.001)/2 : H_in0;   // tuck: rounded up to 0.5 mm (keeps the mesh clean)
tie_z   = b14 ? [zt + tie14_rise[0], zt + tie14_rise[1]] : [zt + tie_rise[0], zt + tie_rise[1]];        // bottoms of the two tie slots
tie_x0  = compact ? px0 + pf[0] - 14.3 : b14 ? px0 + tie14_x : tie_x;   // between the two gutter fins
// compact carrier: where the lid fins press and the body supports sit, as x
// ranges measured from the board's port edge. Gutter side: on spare column 14.
// Connector side: on spare row 1 and on the free holes beside GPIO 25, between
// the MOTOR and PAW connectors.
cf_gutter = [[pf[0] - 22, pf[0] - 16], [pf[0] - 8, pf[0] - 2]];
cf_strip  = [[gx0 + (n_rows - row25)*2.54 - 1.5, gx0 + (n_rows - row25)*2.54 + 1.5],
             [pf[0] - 2.4, pf[0] - 0.2]];

n_exits  = motor_in_box ? n_leads - 1 : n_leads;
fence_len= (n_exits - 1)*exit_pitch + 3 + jog + 3.5;
fence_y0 = (tuck ? W_in - blk : div_y0) - fence_len;   // tuck: clear of the corner screw boss
notch_w  = lead_d + 0.3;
notch_d  = 2*lead_d - lead_squeeze;
function fence_notch_y(i) = fence_y0 + 3 + i*exit_pitch;
function wall_notch_y(i)  = fence_notch_y(i) + jog;

// USB socket centres on the port wall
esp_mouth_x = px0 + esp_x0r - usb_ov;   // ESP32 USB socket mouth (>= tol)
ue_y = py0 + esp_center_y;
ue_z = zt + hdr_h + pin_spacer_h + esp_pcb_t + esp_usb_h;
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

// lid screw axes (tuck: only the two at the antenna end)
boss_all = [[boss_off, boss_off], [L_in - boss_off, boss_off],
            [boss_off, W_in - boss_off], [L_in - boss_off, W_in - boss_off]];
boss_xy = tuck ? [boss_all[1], boss_all[3]] : boss_all;
// perfboard corner holes
perf_hole_xy = [for (ix = [0, 1], iy = [0, 1])
    [px0 + (ix ? pf[0] - perf_hole_inset : perf_hole_inset),
     py0 + (iy ? pf[1] - perf_hole_inset : perf_hole_inset)]];

L_out = L_in + 2*wall;  W_out = W_in + 2*wall;  H_out = floor_t + H_in + lid_t;

// The charger sits under the ESP32, between the two header rows, where the
// carrier has no solder joints or links. Its screw terminal still needs air.
assert(usb || perf_standoff_h >= chg_standoff_h + chg[2] + chg_top_h + 0.8,
       "perf_standoff_h too low: the charger's screw terminal would touch the carrier");
assert(usb || sw_zc + sw_recess[1]/2 + 1.2 <= zs - 0.5, "switch recess reaches the perfboard");
assert(!usb || perf_standoff_usb >= 4, "perf_standoff_usb too low for the carrier's solder joints");
assert(!usb || !cable_tie || tie_z[1] + tie_slot[1] + 1.5 <= H_in - rim_h, "tie slot reaches the lid rim");
assert(!motor_pocket || lay14 || motor_t + 0.4 + 1.2 <= gutter, "motor pocket does not fit in the gutter");
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
    for (b = boss_xy) if (b[1] < W_in/2) {
        sx = b[0] < L_in/2 ? -1 : 1;
        hull() {
            translate([b[0], b[1], -ov]) cylinder(r = boss_r, h = H_in + ov);
            translate([b[0] + sx*(boss_off + ov)/2, (boss_off - ov)/2 - ov/2, -ov + (H_in + ov)/2])
                cube([boss_off + ov, boss_off + ov, H_in + ov], center = true);
        }
    }
    if (usb) {
        // far-side corners: the same round columns, mirrored
        for (b = boss_xy) if (b[1] > W_in/2) {
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
    x1 = px0 + pf[0];
    // port end, gutter side
    // (tuck: the board lies against both long walls, which locate it; no side lips)
    box(-ov, px0 + p, bay_y0 - lip, py0 + p, -ov, zs);
    if (!tuck) box(-ov, px0 + p, bay_y0 - lip, bay_y0, -ov, zt);
    // port end, battery side (the divider is its fence)
    box(-ov, px0 + p, div_y0 - tol - p, div_y0 + ov, -ov, zs);
    if (usb && !tuck) {   // no divider: the far edge gets its own lips, like the gutter side
        box(-ov, px0 + p, div_y0, div_y0 + lip, -ov, zt);
        box(x1 - p, fence_x0 + lip, div_y0, div_y0 + lip, -ov, zt);
    }
    // antenna end, gutter side
    box(x1 - p, fence_x0 + lip, bay_y0 - lip, py0 + p, -ov, zs);
    if (!tuck) box(x1 - p, fence_x0 + lip, bay_y0 - lip, bay_y0, -ov, zt);
    box(fence_x0, fence_x0 + lip, bay_y0 - lip, py0 + p, -ov, zt);
    // antenna end, battery side (the strain-relief fence is its fence)
    box(x1 - p, fence_x0 + ov, div_y0 - tol - p, div_y0 + ov, -ov, zs);
}

// carrier = "compact": the cut board has joints right up to its corners, so it
// rests only on its spare rows (2 mm ledges at both ends) and on small posts
// under the lid fins. Lips at the corners and the antenna end locate it; at the
// port end the wall does (or, on the 30-pin board, the ESP32's own USB socket).
module compact_supports() {
    d = 2.0; wy = 8; lip = 1.2;
    zl = zt - 0.4;                             // lips stop short of the board's top face
    x1 = px0 + pf[0];  xl = x1 + ptol;         // antenna end of the board, and its lip
    ya = py0;  yb = py0 + pf[1];
    for (yy = [[bay_y0 - lip, ya + wy], [yb - wy, div_y0 + lip]]) {
        box(-ov, px0 + d, yy[0], yy[1], -ov, zs);          // port end ledge
        box(x1 - d, xl + lip, yy[0], yy[1], -ov, zs);      // antenna end ledge
        box(xl, xl + lip, yy[0], yy[1], -ov, zl);          // antenna end lip
    }
    for (xx = [[-ov, px0 + d], [x1 - d, xl + lip]]) {      // side lips at the corners
        box(xx[0], xx[1], bay_y0 - lip, bay_y0, -ov, zl);
        box(xx[0], xx[1], div_y0, div_y0 + lip, -ov, zl);
    }
    for (f = cf_gutter) box(px0 + f[0], px0 + f[1], bay_y0 - lip, ya + d, -ov, zs);
    for (f = cf_strip)  box(px0 + f[0], px0 + f[1], yb - d, div_y0 + lip, -ov, zs);
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

// tuck: everything on the port side of the sloping face where the lid meets
// the lip. The body keeps this slice of the lid's shape; the lid loses it.
module tuck_region(grow = 0) {
    translate([0, W_in + wall + 1, 0]) rotate([90, 0, 0]) linear_extrude(W_in + 2*wall + 2)
        // (the sloping face is carried on 1 mm below the lid so no cut lies in the lid's own underside)
        polygon([[-wall - 1, H_in - 1], [tuck_toe + grow - 1, H_in - 1],
                 [tuck_reach + grow, H_in + tuck_reach - tuck_toe],
                 [tuck_reach + grow, H_in + lid_t + 1], [-wall - 1, H_in + lid_t + 1]]);
}

module body() {
    difference() {
        union() {
            difference() { shell(-floor_t, H_in); cavity(); }
            // the port wall carries on up beside the lid and leans over it at 45 degrees
            if (tuck) intersection() { shell(H_in + lid_t, H_in); tuck_region(); }
            lid_bosses();
            if (compact) compact_supports(); else perf_posts();
            if (!usb) {
                divider();
                chg_mount();
                switch_block();
            }
            if (motor_pocket && !lay14) motor_pocket_walls();
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
            box(tie_x0, tie_x0 + tie_slot[0], -wall - 1, 0.5, z, z + tie_slot[1]);
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
        if (!compact) for (h = perf_hole_xy) translate([h[0], h[1], max(zs - 7, 0.8 - floor_t)])
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
    yb = py0 + pf[1];                          // battery-side edge of the carrier
    if (compact) {
        for (f = cf_strip)  fin(f[0], f[1], yb - 1.8, yb - 0.3, yb - 4.6, yb - 0.3);
        for (f = cf_gutter) fin(f[0], f[1], py0 + 0.3, py0 + 1.5, py0 - 2.2, py0 + 1.5);
    } else if (b14) {
        // the board lies against both long walls, so the fins grow out of the lid rim
        for (f = hd14_far)    fin(f[0], f[1], yb - 1.8, yb - 0.2, yb - 4.6, yb - 0.2);
        // (kept slim on this side: the ESP32 is only 2.2 mm from the wall)
        for (f = hd14_gutter) fin(f[0], f[1], py0 + 0.2, py0 + 1.3, rim_gap, py0 + 1.5);
    } else {
        for (f = hd_batt_side) fin(f[0], f[1], yb - 1.8, yb - 0.2, yb - 4.6, yb - 0.2);
        fin(hd_batt_post[0], hd_batt_post[1], yb - 5.0, yb - 0.2, yb - 6.5, yb - 0.2);
        for (f = hd_gutter_side) fin(f[0], f[1], py0 + 0.2, py0 + 1.4, py0 - 2.2, py0 + 1.4);
    }
}
module lid() {
    g = rim_gap;
    difference() {
        union() {
            shell(H_in + lid_t, H_in);
            rx0 = tuck ? tuck_reach + 1.0 : blk + 0.6;   // tuck: no screw boss at the port end
            if (!tuck) rim_bar(g, g + rim_t, blk + 0.6, (usb ? W_in - blk : div_y0) - 0.6);   // port wall
            if (usb) rim_bar(rx0, min(L_in - blk, fence_x0) - 0.6,
                             W_in - g - rim_t, W_in - g);                  // far wall
            rim_bar(rx0, L_in - blk - 0.6, g, g + rim_t);                   // gutter wall
            rim_bar(L_in - g - rim_t, L_in - g, blk + 0.6, fence_y0 - 0.6); // antenna wall
            if (holddown) holddown_fins();
        }
        if (tuck) tuck_region(tuck_gap);
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
