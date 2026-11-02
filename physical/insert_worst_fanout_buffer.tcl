# Split one selected sink from the high-fanout net24915 near its AOI load.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_moved2_route.odb 5_read_control_worst_buffer_moved2.sdc
set_propagated_clock [all_clocks]
set sinks [get_pins _193947_/A1]
if {![llength $sinks]} {error "Target load pin _193947_/A1 not found"}
insert_buffer -buffer_cell gf180mcu_fd_sc_mcu9t5v0__buf_20 \
  -net net24915 -load_pins $sinks \
  -location {1706880 12216960} \
  -buffer_name read_control_net24915_local \
  -net_name net24915_local
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_split.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_split.sdc
puts "WORST_FANOUT_BUFFER_INSERT complete"
