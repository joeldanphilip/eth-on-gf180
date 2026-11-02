source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_hold_repaired.odb 4_hold_repaired.sdc
set_propagated_clock [all_clocks]
estimate_parasitics -placement
# Limit each attempt, save its physical result, and measure both analyses.
repair_timing -setup -max_passes 50 -max_iterations 100 -repair_tns 100
detailed_placement
estimate_parasitics -placement
repair_timing -hold -allow_setup_violations -max_passes 100 -max_iterations 1000
detailed_placement
check_placement -verbose
estimate_parasitics -placement
write_db $::env(RESULTS_DIR)/4_setup_repaired.odb
write_sdc $::env(RESULTS_DIR)/4_setup_repaired.sdc
set physical_qor_stage setup_repaired
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
