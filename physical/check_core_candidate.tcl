source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_core_optimized.odb 4_clock_latency_trial.sdc
set_propagated_clock [all_clocks]
estimate_parasitics -placement
set physical_qor_stage core_candidate_original_constraints
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
foreach corner {WC BC TC} {
  report_checks -scenes [list $corner] -from [all_registers -clock_pins] -to [all_registers -data_pins] -path_delay min_max -group_path_count 3 -format full_clock_expanded > $::env(REPORTS_DIR)/core_candidate_${corner}_internal.rpt
}
