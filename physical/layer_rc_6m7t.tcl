# 6LM/7t global-route RC model.  MetalTop is the sixth GF180 routing layer
# name in the public LEF (not Metal6); Via5 connects Metal5 to MetalTop.
set_layer_rc -layer Metal2 -resistance [expr {0.09/0.28}] -capacitance 1.35357e-4
set_layer_rc -layer Metal3 -resistance [expr {0.09/0.28}] -capacitance 1.46141e-4
set_layer_rc -layer Metal4 -resistance [expr {0.09/0.28}] -capacitance 1.50688e-4
set_layer_rc -layer Metal5 -resistance [expr {0.04/0.44}] -capacitance 1.55595e-4
set_layer_rc -layer MetalTop -resistance [expr {0.04/0.44}] -capacitance 3.94e-5

if { [info exists ::env(CORNER)] && $::env(CORNER) == "WC" } {
  set via_resistance 16.845
} elseif { [info exists ::env(CORNER)] && $::env(CORNER) == "BC" } {
  set via_resistance 4.23
} else {
  set via_resistance 4.5
}
foreach via {Via1 Via2 Via3 Via4 Via5} {
  set_layer_rc -via $via -resistance $via_resistance
}

set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
