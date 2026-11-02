# Corner-specific OpenRCX extraction for the localized ECO candidate.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_read_control_final.odb 6_read_control_final.sdc
if {![design_is_routed]} {error "Refusing extraction of an unrouted candidate"}
define_process_corner -ext_model_index 0 X
puts "READ_CONTROL_EXTRACTION corner=$::env(CORNER) rules=$::env(RCX_RULES)"
extract_parasitics -ext_model_file $::env(RCX_RULES) -corner_cnt 1
write_spef $::env(RESULTS_DIR)/6_read_control_$::env(CORNER).spef
puts "READ_CONTROL_EXTRACTION complete corner=$::env(CORNER)"
