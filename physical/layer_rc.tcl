# OpenROAD command units are ohm, pF, um in the pinned ORFS flow.
# Preserve the selected LEF sheet resistance / minimum wire width. The platform
# setRC.tcl's 2.25636e-4 numbers are not ohm/um and understate R in this tool.
# C estimates are the public GF180 ORFS per-length values. These are placement
# estimates, not a substitute for final corner-specific OpenRCX extraction.
set_layer_rc -layer Metal2 -resistance [expr {0.09/0.28}] -capacitance 1.35357e-4
set_layer_rc -layer Metal3 -resistance [expr {0.09/0.28}] -capacitance 1.46141e-4
set_layer_rc -layer Metal4 -resistance [expr {0.09/0.28}] -capacitance 1.50688e-4
set_layer_rc -layer Metal5 -resistance [expr {0.04/0.44}] -capacitance 1.55595e-4

# The platform setRC.tcl also changes the via model by PVT corner.  Because
# this file replaces that layer setup, retain those values explicitly; leaving
# them at the OpenROAD default would make every routed via look ideal.
if { [info exists ::env(CORNER)] && $::env(CORNER) == "WC" } {
  set via_resistance 16.845
} elseif { [info exists ::env(CORNER)] && $::env(CORNER) == "BC" } {
  set via_resistance 4.23
} else {
  set via_resistance 4.5
}
foreach via {Via1 Via2 Via3 Via4} {
  set_layer_rc -via $via -resistance $via_resistance
}

set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
