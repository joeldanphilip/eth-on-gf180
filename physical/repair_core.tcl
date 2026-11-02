# Optimization-only analysis view: isolate core paths from provisional I/O
# budgets. Never export this view's SDC or use its slack as signoff evidence.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_port_setup.odb 4_port_setup.sdc
set_propagated_clock [all_clocks]
unset_dont_touch [get_nets *]
set_dont_use [get_lib_cells */*__dly*]
set_dont_use [get_lib_cells */*_1]
foreach port [all_inputs] {
  if {[get_full_name $port] ni {logic_clk rx_clk tx_clk}} {
    set_false_path -from $port
  }
}
set_false_path -to [all_outputs]
estimate_parasitics -placement
puts "CORE_OPTIMIZATION_ONLY: I/O budgets excluded in this temporary analysis view"
repair_timing -setup -max_passes 100 -max_iterations 200 -repair_tns 100
detailed_placement
check_placement -verbose
estimate_parasitics -placement
report_worst_slack -max -digits 4
report_worst_slack -min -digits 4
write_db $::env(RESULTS_DIR)/4_core_optimized.odb
# No write_sdc: a fresh invocation must restore the original complete view.
