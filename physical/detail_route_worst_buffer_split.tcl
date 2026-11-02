# Re-route the selected-load buffer split candidate.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split.odb 5_read_control_worst_buffer_split.sdc
source $::env(FASTROUTE_TCL)
set_routing_layers -clock Metal4-Metal5
set_propagated_clock [all_clocks]
set additional_args ""
append_env_var additional_args dbProcessNode -db_process_node 1
append_env_var additional_args OR_SEED -or_seed 1
append_env_var additional_args OR_K -or_k 1
append_env_var additional_args VIA_IN_PIN_MIN_LAYER -via_in_pin_bottom_layer 1
append_env_var additional_args VIA_IN_PIN_MAX_LAYER -via_in_pin_top_layer 1
append_env_var additional_args DISABLE_VIA_GEN -disable_via_gen 0
append_env_var additional_args REPAIR_PDN_VIA_LAYER -repair_pdn_vias 1
append additional_args " -verbose 1"
set arguments [expr {[env_var_exists_and_non_empty DETAILED_ROUTE_ARGS] ? $::env(DETAILED_ROUTE_ARGS) : [concat $additional_args {-drc_report_iter_step 5}]}]
set all_args [concat [list -output_drc $::env(REPORTS_DIR)/read_control_worst_buffer_split_drc.rpt -output_maze $::env(RESULTS_DIR)/read_control_worst_buffer_split_maze.log] $arguments]
log_cmd detailed_route {*}$all_args
if {![design_is_routed]} {puts "WORST_FANOUT_BUFFER_ROUTE design_is_routed=0_after_drt"}
check_antennas -report_file $::env(REPORTS_DIR)/read_control_worst_buffer_split_antennas.log
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_split_route.odb
puts "WORST_FANOUT_BUFFER_ROUTE complete"
