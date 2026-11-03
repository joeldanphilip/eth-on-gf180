source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_setup_place25436_final.odb 6_setup_place25436_final.sdc
if {![design_is_routed]} {puts "SETUP_ECO_25436_EXTRACTION design_is_routed=0_after_eco_drt"}
define_process_corner -ext_model_index 0 X
puts "SETUP_ECO_25436_EXTRACTION corner=$::env(CORNER) rules=$::env(RCX_RULES)"
extract_parasitics -ext_model_file $::env(RCX_RULES) -corner_cnt 1
write_spef $::env(RESULTS_DIR)/6_setup_place25436_$::env(CORNER).spef
puts "SETUP_ECO_25436_EXTRACTION complete corner=$::env(CORNER)"
