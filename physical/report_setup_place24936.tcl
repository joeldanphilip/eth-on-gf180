source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_setup_place24936_fill.odb 6_setup_place24936_fill.sdc
set_propagated_clock [all_clocks]
global_connect
orfs_write_db $::env(RESULTS_DIR)/6_setup_place24936_final.odb
source $::env(SCRIPTS_DIR)/deleteRoutingObstructions.tcl
deleteRoutingObstructions
write_def $::env(RESULTS_DIR)/6_setup_place24936_final.def
write_verilog $::env(RESULTS_DIR)/6_setup_place24936_final.v -remove_cells [find_physical_only_masters]
write_sdc $::env(RESULTS_DIR)/6_setup_place24936_final.sdc
puts "SETUP_ECO_REPORT complete"
