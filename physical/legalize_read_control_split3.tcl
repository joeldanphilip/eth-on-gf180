# Legalize ECO buffers in split3 before final fill insertion.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split3_route.odb 5_read_control_worst_buffer_split3.sdc
set_propagated_clock [all_clocks]
detailed_placement
check_placement -verbose
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_split3_legalized.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_split3_legalized.sdc
puts "READ_CONTROL_SPLIT3_LEGALIZE complete"
