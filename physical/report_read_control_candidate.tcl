# Produce the exact database/DEF/netlist used for candidate signoff.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_read_control_fill.odb 6_read_control_fill.sdc
set_propagated_clock [all_clocks]
global_connect

orfs_write_db $::env(RESULTS_DIR)/6_read_control_final.odb
source $::env(SCRIPTS_DIR)/deleteRoutingObstructions.tcl
deleteRoutingObstructions
write_def $::env(RESULTS_DIR)/6_read_control_final.def
write_verilog $::env(RESULTS_DIR)/6_read_control_final.v \
  -remove_cells [find_physical_only_masters]
write_sdc $::env(RESULTS_DIR)/6_read_control_final.sdc
puts "READ_CONTROL_FINAL_REPORT complete"
