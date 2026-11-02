# Split the remaining long net24870 branch feeding the two worst AOI loads.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split2_route.odb 5_read_control_worst_buffer_split2.sdc
set_propagated_clock [all_clocks]
set sinks [get_pins {_193928_/B2 _193959_/B2}]
if {[llength $sinks] != 2} {error "Expected two target load pins on net24870"}
insert_buffer -buffer_cell gf180mcu_fd_sc_mcu9t5v0__buf_20 \
  -net net24870 -load_pins $sinks \
  -location {1713600 11890080} \
  -buffer_name read_control_net24870_pair \
  -net_name net24870_pair
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_split3.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_split3.sdc
puts "THIRD_FANOUT_BUFFER_INSERT complete"
