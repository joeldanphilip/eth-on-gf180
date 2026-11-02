# Legalize split5 before routing.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split5.odb 5_read_control_worst_buffer_split5.sdc
set_propagated_clock [all_clocks]
detailed_placement
check_placement -verbose
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_split5_legalized.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_split5_legalized.sdc
puts "READ_CONTROL_SPLIT5_LEGALIZE complete"
