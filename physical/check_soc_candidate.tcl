source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_core_optimized.odb 4_clock_latency_trial.sdc
set_propagated_clock [all_clocks]
source /home/joelphilip/Documents/ethernet_formal/physical/soc_interface.tcl
estimate_parasitics -placement
set physical_qor_stage soc_core_candidate
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
