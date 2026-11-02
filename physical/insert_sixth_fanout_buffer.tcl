# Split the next long RX bank-select branch feeding the worst AOI.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split5_route.odb 5_read_control_worst_buffer_split5_legalized.sdc
set_propagated_clock [all_clocks]
set sinks [get_pins _215198_/B2]
if {[llength $sinks] != 1} {error "Target load pin _215198_/B2 not found"}
insert_buffer -buffer_cell gf180mcu_fd_sc_mcu9t5v0__buf_20 \
  -net net22622 -load_pins $sinks \
  -location {6516160 11047680} \
  -buffer_name read_control_net22622_local \
  -net_name net22622_local
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_split6.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_split6.sdc
puts "SIXTH_FANOUT_BUFFER_INSERT complete"
