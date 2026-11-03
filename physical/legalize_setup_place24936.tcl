source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_setup_place24936_resize.odb 5_setup_place24936_resize.sdc
set_propagated_clock [all_clocks]
detailed_placement
check_placement -verbose
write_db $::env(RESULTS_DIR)/5_setup_place24936_resize_legalized.odb
write_sdc $::env(RESULTS_DIR)/5_setup_place24936_resize_legalized.sdc
puts "SETUP_ECO_LEGALIZE complete"
