# Sky130HD example IP-block constraints.  Replace I/O budgets with SoC-level
# constraints when this MAC is integrated into its parent design.
create_clock -name logic -period 8.000 [get_ports logic_clk]
create_clock -name tx -period 8.000 [get_ports tx_clk]
create_clock -name rx -period 8.000 [get_ports rx_clk]

set_clock_groups -asynchronous -group logic -group tx -group rx
set_clock_uncertainty 0.100 [all_clocks]
set_clock_transition 0.100 [all_clocks]
set_input_transition 0.100 [all_inputs]

set_input_delay -max 1.0 -clock logic [get_ports {tx_axis_tdata* tx_axis_tkeep* tx_axis_tvalid tx_axis_tlast tx_axis_tuser rx_axis_tready}]
set_input_delay -min 0.2 -clock logic [get_ports {tx_axis_tdata* tx_axis_tkeep* tx_axis_tvalid tx_axis_tlast tx_axis_tuser rx_axis_tready}]
set_output_delay -max 1.0 -clock logic [get_ports {rx_axis_tdata* rx_axis_tkeep* rx_axis_tvalid rx_axis_tlast rx_axis_tuser tx_axis_tready tx_error_underflow tx_fifo_* rx_error_* rx_fifo_*}]
set_output_delay -min 0.2 -clock logic [get_ports {rx_axis_tdata* rx_axis_tkeep* rx_axis_tvalid rx_axis_tlast rx_axis_tuser tx_axis_tready tx_error_underflow tx_fifo_* rx_error_* rx_fifo_*}]

set_input_delay -max 1.0 -clock rx [get_ports {gmii_rxd* gmii_rx_dv gmii_rx_er rx_clk_enable rx_mii_select cfg_rx_enable}]
set_input_delay -min 0.2 -clock rx [get_ports {gmii_rxd* gmii_rx_dv gmii_rx_er rx_clk_enable rx_mii_select cfg_rx_enable}]
set_input_delay -max 1.0 -clock tx [get_ports {tx_clk_enable tx_mii_select cfg_ifg* cfg_tx_enable}]
set_input_delay -min 0.2 -clock tx [get_ports {tx_clk_enable tx_mii_select cfg_ifg* cfg_tx_enable}]
set_output_delay -max 1.0 -clock tx [get_ports {gmii_txd* gmii_tx_en gmii_tx_er}]
set_output_delay -min 0.2 -clock tx [get_ports {gmii_txd* gmii_tx_en gmii_tx_er}]

set_false_path -from [get_ports {*_rst}]
set_input_delay 0.0 -clock logic [get_ports logic_rst]
set_input_delay 0.0 -clock tx [get_ports tx_rst]
set_input_delay 0.0 -clock rx [get_ports rx_rst]
set_load 0.010 [all_outputs]
