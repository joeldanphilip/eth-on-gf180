source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_top_electrical_small_split.odb 5_read_control_top_electrical_small_split.sdc
set_propagated_clock [all_clocks]
detailed_placement
check_placement -verbose
write_db $::env(RESULTS_DIR)/5_read_control_top_electrical_small_split_legalized.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_top_electrical_small_split_legalized.sdc
puts "TOP_ELECTRICAL_SMALL_SPLIT_LEGALIZE complete"
