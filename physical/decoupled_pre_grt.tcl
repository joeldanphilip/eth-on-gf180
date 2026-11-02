# Routing settings are process-local; restore the platform policy after ODB
# import rather than relying on the earlier floorplan process to retain it.
source $::env(FASTROUTE_TCL)
set_routing_layers -clock Metal4-Metal5
source /home/joelphilip/Documents/ethernet_formal/physical/pre_global_route.tcl
# Direct checkpoint replay sanitizes some platform variables. The selected
# GF180 5 V nine-track library has fixed tie-cell masters and output pins.
if {![info exists ::env(TIEHI_CELL_AND_PORT)]} {
  set ::env(TIEHI_CELL_AND_PORT) "gf180mcu_fd_sc_mcu9t5v0__tieh Z"
}
if {![info exists ::env(TIELO_CELL_AND_PORT)]} {
  set ::env(TIELO_CELL_AND_PORT) "gf180mcu_fd_sc_mcu9t5v0__tiel ZN"
}
source /home/joelphilip/Documents/ethernet_formal/physical/connect_constants.tcl
puts "SOC_ROUTING_POLICY signal=Metal2-Metal5 clock=Metal4-Metal5 platform_capacity_reserve=25%"
