source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_cts.odb 4_cts.sdc
set_propagated_clock [all_clocks]
set_dont_use $::env(DONT_USE_CELLS)
estimate_parasitics -placement
repair_timing -setup -setup_margin 0.10 -hold_margin 0.03 \
  -repair_tns 100 -max_passes 200 -max_iterations 500
detailed_placement
estimate_parasitics -placement
repair_timing -hold -hold_margin 0.03 -max_passes 100 -max_iterations 1000
detailed_placement
check_placement -verbose
estimate_parasitics -placement
write_db $::env(RESULTS_DIR)/4_2_timing_repaired.odb
write_sdc $::env(RESULTS_DIR)/4_2_timing_repaired.sdc
set physical_qor_stage soc_cts_repaired
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
