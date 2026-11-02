# Split the current TX bank-select branch feeding the worst AOI.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split6_route.odb 5_read_control_worst_buffer_split6_legalized.sdc
set_propagated_clock [all_clocks]
set sinks [get_pins _191822_/A1]
if {[llength $sinks] != 1} {error "Target load pin _191822_/A1 not found"}
insert_buffer -buffer_cell gf180mcu_fd_sc_mcu9t5v0__buf_20 \
  -net net21684 -load_pins $sinks \
  -location {9325120 13134240} \
  -buffer_name read_control_net21684_local \
  -net_name net21684_local
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_split7.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_split7.sdc
puts "SEVENTH_FANOUT_BUFFER_INSERT complete"
