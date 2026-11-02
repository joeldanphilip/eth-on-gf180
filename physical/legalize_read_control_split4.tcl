# Legalize the split4 ECO buffer before routing.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split4.odb 5_read_control_worst_buffer_split4.sdc
set_propagated_clock [all_clocks]
detailed_placement
check_placement -verbose
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_split4_legalized.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_split4_legalized.sdc
puts "READ_CONTROL_SPLIT4_LEGALIZE complete"
