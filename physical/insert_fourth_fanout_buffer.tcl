# Split the long TX FIFO control branch feeding the current worst AOI.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split3_legalized_route.odb 5_read_control_worst_buffer_split3_legalized.sdc
set_propagated_clock [all_clocks]
set sinks [get_pins _186299_/A1]
if {[llength $sinks] != 1} {error "Target load pin _186299_/A1 not found"}
insert_buffer -buffer_cell gf180mcu_fd_sc_mcu9t5v0__buf_20 \
  -net net21574 -load_pins $sinks \
  -location {6845440 4656960} \
  -buffer_name read_control_net21574_local \
  -net_name net21574_local
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_split4.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_split4.sdc
puts "FOURTH_FANOUT_BUFFER_INSERT complete"
