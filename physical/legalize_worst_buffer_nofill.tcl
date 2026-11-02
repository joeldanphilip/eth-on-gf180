# Legalize the widened buffer and its neighbors before filler insertion.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_nofill.odb 5_read_control_worst_buffer_nofill.sdc
detailed_placement -incremental
check_placement -verbose
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_legal.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_legal.sdc
puts "READ_CONTROL_WORST_BUFFER_LEGALIZE complete"
