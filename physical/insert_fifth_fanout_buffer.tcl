# Split the remaining long RX bank-select branch feeding the worst AOI.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split4_route.odb 5_read_control_worst_buffer_split4_legalized.sdc
set_propagated_clock [all_clocks]
set sinks [get_pins _193947_/C2]
if {[llength $sinks] != 1} {error "Target load pin _193947_/C2 not found"}
insert_buffer -buffer_cell gf180mcu_fd_sc_mcu9t5v0__buf_20 \
  -net net25412 -load_pins $sinks \
  -location {1706880 12116160} \
  -buffer_name read_control_net25412_local \
  -net_name net25412_local
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_split5.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_split5.sdc
puts "FIFTH_FANOUT_BUFFER_INSERT complete"
