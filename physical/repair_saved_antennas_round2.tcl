# Second isolated antenna pass, starting from the ratio-margin-20 candidate.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_antenna_ratio20.odb 5_read_control_sized.sdc
set_propagated_clock [all_clocks]
global_connect
puts "READ_CONTROL_ANTENNA_ROUND2 baseline"
check_antennas -report_file $::env(REPORTS_DIR)/read_control_antenna_round2_before.log
set changed [repair_antennas -iterations 1 -ratio_margin 20 -diode_only]
puts "READ_CONTROL_ANTENNA_ROUND2 repair_changed=$changed"

set additional_args ""
append_env_var additional_args dbProcessNode -db_process_node 1
append_env_var additional_args OR_SEED -or_seed 1
append_env_var additional_args OR_K -or_k 1
append_env_var additional_args VIA_IN_PIN_MIN_LAYER -via_in_pin_bottom_layer 1
append_env_var additional_args VIA_IN_PIN_MAX_LAYER -via_in_pin_top_layer 1
append_env_var additional_args DISABLE_VIA_GEN -disable_via_gen 0
append_env_var additional_args REPAIR_PDN_VIA_LAYER -repair_pdn_vias 1
append additional_args " -verbose 1"
set arguments [expr {
  [env_var_exists_and_non_empty DETAILED_ROUTE_ARGS] ? $::env(DETAILED_ROUTE_ARGS) :
  [concat $additional_args {-drc_report_iter_step 5}]
}]
set all_args [concat [list \
  -output_drc $::env(REPORTS_DIR)/read_control_antenna_round2_drc.rpt \
  -output_maze $::env(RESULTS_DIR)/read_control_antenna_round2_maze.log] $arguments]
log_cmd detailed_route {*}$all_args
check_antennas -report_file $::env(REPORTS_DIR)/read_control_antenna_round2_after.log
if {![design_is_routed]} {error "Antenna round2 candidate is not routed"}
write_db $::env(RESULTS_DIR)/5_read_control_antenna_round2.odb
puts "READ_CONTROL_ANTENNA_ROUND2 complete"
