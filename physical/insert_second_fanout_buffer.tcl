# Split the second high-fanout input of the current worst AOI load.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split_route.odb 5_read_control_worst_buffer_split.sdc
set_propagated_clock [all_clocks]
set sinks [get_pins _193947_/B2]
if {![llength $sinks]} {error "Target load pin _193947_/B2 not found"}
insert_buffer -buffer_cell gf180mcu_fd_sc_mcu9t5v0__buf_20 \
  -net net24870 -load_pins $sinks \
  -location {1706880 12216960} \
  -buffer_name read_control_net24870_local \
  -net_name net24870_local
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_split2.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_split2.sdc
puts "SECOND_FANOUT_BUFFER_INSERT complete"
