# Local setup ECO identified from the extracted WC critical path.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split7_route.odb 5_read_control_worst_buffer_split7_legalized.sdc
set_propagated_clock [all_clocks]
global_connect
set inst [[ord::get_db_block] findInst place24936]
if {$inst eq "NULL"} {error "Critical buffer place24936 not found"}
set master [[$inst getMaster] getName]
puts "SETUP_ECO place24936 master_before=$master"
if {$master ne "gf180mcu_fd_sc_mcu9t5v0__buf_8"} {error "Unexpected place24936 master=$master"}
replace_cell place24936 gf180mcu_fd_sc_mcu9t5v0__buf_20
puts "SETUP_ECO place24936 master_after=[[$inst getMaster] getName]"
write_db $::env(RESULTS_DIR)/5_setup_place24936_resize.odb
write_sdc $::env(RESULTS_DIR)/5_setup_place24936_resize.sdc
puts "SETUP_ECO_RESIZE complete"
