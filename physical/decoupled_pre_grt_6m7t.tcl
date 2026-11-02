# Restore routing policy after ODB import for the GF180 6LM/7t profile.
source $::env(FASTROUTE_TCL)
set_routing_layers -clock Metal4-MetalTop
source /home/joelphilip/Documents/ethernet_formal/physical/pre_global_route.tcl
if {![info exists ::env(TIEHI_CELL_AND_PORT)]} {
  set ::env(TIEHI_CELL_AND_PORT) "gf180mcu_fd_sc_mcu7t5v0__tieh Z"
}
if {![info exists ::env(TIELO_CELL_AND_PORT)]} {
  set ::env(TIELO_CELL_AND_PORT) "gf180mcu_fd_sc_mcu7t5v0__tiel ZN"
}
source /home/joelphilip/Documents/ethernet_formal/physical/connect_constants.tcl
puts "SOC_ROUTING_POLICY signal=Metal2-MetalTop clock=Metal4-MetalTop platform_capacity_reserve=25%"
