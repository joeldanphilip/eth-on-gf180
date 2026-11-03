source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_read_control_small_final.odb 6_read_control_small_final.sdc
if {![design_is_routed]} {puts "TOP_ELECTRICAL_SMALL_EXTRACTION design_is_routed=0_after_eco_drt"}
define_process_corner -ext_model_index 0 X
puts "TOP_ELECTRICAL_SMALL_EXTRACTION corner=$::env(CORNER) rules=$::env(RCX_RULES)"
extract_parasitics -ext_model_file $::env(RCX_RULES) -corner_cnt 1
write_spef $::env(RESULTS_DIR)/6_read_control_small_$::env(CORNER).spef
puts "TOP_ELECTRICAL_SMALL_EXTRACTION complete corner=$::env(CORNER)"
