# Resume the clean routed checkpoint without its later filler cells.
# Native buffering/sizing preserves logic; no RTL or clock constraint changes.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_2_route.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]
global_connect
source $::env(FASTROUTE_TCL)
set_routing_layers -clock Metal4-Metal5
if {![grt::have_routes]} {error "Missing saved route guides"}
foreach corner {WC BC TC} {
  read_spef -corner $corner $::env(RESULTS_DIR)/6_${corner}.spef
}
set_dont_use {*_1 *__dly*}
puts "EXTRACTED_CONTROL_REPAIR baseline_from_corner_SPEFs"
report_worst_slack -max -digits 4
report_worst_slack -min -digits 4
global_route -start_incremental
repair_design -max_wire_length 800 -slew_margin 10 -cap_margin 10 -verbose
detailed_placement
check_placement -verbose
global_route -end_incremental -resistance_aware \
  -congestion_report_file $::env(REPORTS_DIR)/control_buffer_congestion.rpt
estimate_parasitics -global_routing
puts "EXTRACTED_CONTROL_REPAIR after_wire_and_slew_repair_estimate"
report_worst_slack -max -digits 4
report_worst_slack -min -digits 4
global_route -start_incremental
repair_timing -setup -setup_margin 0.25 -repair_tns 100 \
  -max_passes 100 -max_iterations 300 -skip_pin_swap -skip_gate_cloning \
  -skip_size_down -skip_buffer_removal
detailed_placement
check_placement -verbose
global_route -end_incremental -resistance_aware \
  -congestion_report_file $::env(REPORTS_DIR)/control_timing_congestion.rpt
estimate_parasitics -global_routing
global_connect
set physical_qor_stage control_buffer_repair_estimated
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
write_db $::env(RESULTS_DIR)/5_control_repair.odb
write_sdc -no_timestamp $::env(RESULTS_DIR)/5_control_repair.sdc
