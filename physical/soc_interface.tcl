# Hierarchical integration contract: neighboring SoC registers are clock
# balanced to a representative MAC leaf in each domain. This is an explicit
# assumption for block closure; top-level CTS must validate residual skew.
# Keep the original 8 ns clocks, 1.0/0.2 ns I/O budgets and CDC exceptions.
foreach {domain reference inputs outputs} {
  logic clkbuf_leaf_0_logic_clk/Z {tx_axis_tdata* tx_axis_tkeep* tx_axis_tvalid tx_axis_tlast tx_axis_tuser rx_axis_tready} {rx_axis_tdata* rx_axis_tkeep* rx_axis_tvalid rx_axis_tlast rx_axis_tuser tx_axis_tready tx_error_underflow tx_fifo_* rx_error_* rx_fifo_*}
  rx clkbuf_leaf_0_rx_clk/Z {gmii_rxd* gmii_rx_dv gmii_rx_er rx_clk_enable rx_mii_select cfg_rx_enable} {}
  tx clkbuf_leaf_0_tx_clk/Z {tx_clk_enable tx_mii_select cfg_ifg* cfg_tx_enable} {gmii_txd* gmii_tx_en gmii_tx_er}
} {
  set ref [get_pins $reference]
  if {[llength $ref] != 1} {error "Missing SoC clock reference $reference"}
  set_input_delay -max 1.0 -clock $domain -reference_pin $ref [get_ports $inputs]
  set_input_delay -min 0.2 -clock $domain -reference_pin $ref [get_ports $inputs]
  if {[llength $outputs]} {
    set_output_delay -max 1.0 -clock $domain -reference_pin $ref [get_ports $outputs]
    set_output_delay -min 0.2 -clock $domain -reference_pin $ref [get_ports $outputs]
  }
  puts "SOC_INTERFACE_CONTRACT $domain balanced_to=$reference budget_max=1.0 budget_min=0.2"
}
