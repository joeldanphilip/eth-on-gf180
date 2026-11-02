# Fixed-site version of the single-buffer ECO; preserve all existing routing.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_round2_signoff_route_jumper.odb 5_read_control_round2_sized.sdc
set_propagated_clock [all_clocks]
global_connect
set inst [[ord::get_db_block] findInst place22442]
if {$inst eq "NULL"} {error "Worst-path buffer place22442 not found"}
if {[[$inst getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__buf_12"} {error "Unexpected buffer master"}
replace_cell place22442 gf180mcu_fd_sc_mcu9t5v0__buf_20
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_fixedsite.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_fixedsite.sdc
puts "READ_CONTROL_WORST_BUFFER_FIXEDSITE complete"
