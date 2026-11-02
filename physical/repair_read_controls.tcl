# Localized extracted-RC ECO for the registered bank-select/read-mux cones.
# The clean 5_2_route checkpoint is never overwritten.  All cells and nets
# outside the generated cone manifest are protected from resizing/buffering.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_2_route.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]
global_connect
source $::env(FASTROUTE_TCL)
set_routing_layers -clock Metal4-Metal5
if {![grt::have_routes]} {error "Missing saved route guides"}

# Initialize OpenROAD's parasitic estimator before replacing its estimates
# with the separately extracted corner SPEFs.  This avoids the broad-trial
# failure mode where read_spef alone left the optimizer on wire-load models.
estimate_parasitics -global_routing
foreach corner {WC BC TC} {
  read_spef -corner $corner $::env(RESULTS_DIR)/6_${corner}.spef
}
set_scene WC

set manifest /home/joelphilip/Documents/ethernet_formal/build/read_control_cone/read_control_cone.tcl
if {![file exists $manifest]} {error "Missing cone manifest $manifest"}
source $manifest
if {[llength $read_control_cells] < 3000 || [llength $read_control_cells] > 20000} {
  error "Unexpected allowed cell count [llength $read_control_cells]"
}
if {[llength $read_control_nets] < 3000 || [llength $read_control_nets] > 20000} {
  error "Unexpected allowed net count [llength $read_control_nets]"
}

set allowed_cells {}
foreach row $read_control_cells {lappend allowed_cells [lindex $row 0]}
set allowed_nets $read_control_nets

# Protect the entire design, then release only the combinational cone cells
# and nets.  Capture flops remain protected; repair can insert new local
# buffers on released nets without touching write paths or clock trees.
set_dont_touch [get_cells *]
set_dont_touch [get_nets *]
unset_dont_touch [get_cells $allowed_cells]
unset_dont_touch [get_nets $allowed_nets]

puts "READ_CONTROL_REPAIR baseline cone_cells=[llength $allowed_cells] cone_nets=[llength $allowed_nets]"
report_worst_slack -max -digits 4
report_worst_slack -min -digits 4

global_route -start_incremental
repair_design -max_wire_length 2000 -slew_margin 10 -cap_margin 10 -verbose
detailed_placement -incremental
check_placement -verbose
global_route -end_incremental -resistance_aware \
  -congestion_report_file $::env(REPORTS_DIR)/read_control_cone_congestion.rpt

# This estimate is optimization evidence only.  Signoff will regenerate all
# three SPEFs from the routed candidate before any GDS is accepted.
estimate_parasitics -global_routing
puts "READ_CONTROL_REPAIR after_local_repair estimated_only"
report_worst_slack -max -digits 4
report_worst_slack -min -digits 4
set physical_qor_stage read_control_repair_estimated
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
write_db $::env(RESULTS_DIR)/5_read_control_repair.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_repair.sdc
