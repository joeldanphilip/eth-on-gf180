source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_port_hold_trial.odb 4_port_hold_trial.sdc
set_propagated_clock [all_clocks]
unset_dont_touch [get_nets *]
set block [ord::get_db_block]
set chosen {}
# The first register reached behind each output is an interface launch flop.
foreach pin [get_fanin -to [get_ports {rx_axis_tdata* rx_axis_tvalid rx_axis_tlast rx_axis_tuser tx_axis_tready gmii_txd* gmii_tx_en gmii_tx_er tx_error_underflow rx_error_* tx_fifo_* rx_fifo_*}] -flat -startpoints_only] {
  if {$pin == "" || [catch {get_full_name $pin} pname]} {continue}
  set slash [string last / $pname]
  if {$slash < 0} {continue}
  dict set chosen [string range $pname 0 [expr {$slash-1}]] 1
}
# Capture flops on these low-fanout PHY/configuration inputs also need early
# clocks. Do not move bulk FIFO storage driven by AXI input ports.
foreach pattern {gmii_rxd* gmii_rx_dv gmii_rx_er cfg_ifg*} {
  foreach pin [get_fanout -from [get_ports $pattern] -flat -endpoints_only] {
    if {$pin == "" || [catch {get_full_name $pin} pname]} {continue}
    set slash [string last / $pname]
    if {$slash < 0} {continue}
    dict set chosen [string range $pname 0 [expr {$slash-1}]] 1
  }
}
# These measured internal launch flops feed the bank control cones.
foreach name {_461625_ _461669_} {dict set chosen $name 1}
set changes 0
foreach name [dict keys $chosen] {
  set inst [$block findInst $name]
  if {$inst == "NULL"} {continue}
  set ck [$inst findITerm CLK]
  if {$ck == "NULL"} {continue}
  set old [$ck getNet]
  if {$old == "NULL"} {continue}
  set root ""
  foreach clock_name {logic_clk rx_clk tx_clk} {
    if {[string match *${clock_name}* [$old getName]]} {set root $clock_name; break}
  }
  if {$root == ""} {continue}
  set root_inst [$block findInst clkbuf_0_${root}]
  if {$root_inst == "NULL"} {error "Missing CTS root for $root"}
  set target [[$root_inst findITerm Z] getNet]
  puts "INTERFACE_CLOCK_ECO $name [$old getName] -> [$target getName]"
  $ck connect $target
  incr changes
}
puts "INTERFACE_CLOCK_ECO moved=$changes"
estimate_parasitics -placement
write_db $::env(RESULTS_DIR)/4_interface_skew_trial.odb
write_sdc $::env(RESULTS_DIR)/4_interface_skew_trial.sdc
set physical_qor_stage interface_skew_trial
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
