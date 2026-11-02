source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_clock_latency_trial.odb 4_clock_latency_trial.sdc
set_propagated_clock [all_clocks]
set_dont_use [get_lib_cells */*__dly*]
set_dont_use [get_lib_cells */*_1]
estimate_parasitics -placement
repair_timing -setup -max_passes 50 -max_iterations 100 -repair_tns 100
detailed_placement
estimate_parasitics -placement
write_db $::env(RESULTS_DIR)/4_port_setup.odb
write_sdc $::env(RESULTS_DIR)/4_port_setup.sdc
# Input hold padding must precede shared control logic. Protect internal nets
# during this experiment so the hold optimizer cannot slow full/ready cones.
set_dont_touch [get_nets *]
foreach port [all_inputs] {
  set terminal [[ord::get_db_block] findBTerm [get_full_name $port]]
  if {$terminal != "NULL" && [$terminal getNet] != "NULL"} {
    unset_dont_touch [get_nets [[$terminal getNet] getName]]
  }
}
repair_timing -hold -allow_setup_violations -max_passes 100 -max_iterations 1000
detailed_placement
check_placement -verbose
estimate_parasitics -placement
write_db $::env(RESULTS_DIR)/4_port_hold_trial.odb
write_sdc $::env(RESULTS_DIR)/4_port_hold_trial.sdc
set physical_qor_stage port_hold_trial
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
