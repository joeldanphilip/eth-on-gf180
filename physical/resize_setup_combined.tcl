source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_setup_place24936_resize_route.odb 5_setup_place24936_resize_legalized.sdc
set_propagated_clock [all_clocks]
global_connect
set inst [[ord::get_db_block] findInst place25436]
if {$inst eq "NULL"} {error "Critical buffer place25436 not found"}
set master [[$inst getMaster] getName]
puts "SETUP_COMBINED place25436 master_before=$master"
if {$master ne "gf180mcu_fd_sc_mcu9t5v0__buf_12"} {error "Unexpected place25436 master=$master"}
replace_cell place25436 gf180mcu_fd_sc_mcu9t5v0__buf_20
puts "SETUP_COMBINED place25436 master_after=[[$inst getMaster] getName]"
write_db $::env(RESULTS_DIR)/5_setup_combined_resize.odb
write_sdc $::env(RESULTS_DIR)/5_setup_combined_resize.sdc
puts "SETUP_COMBINED_RESIZE complete"
