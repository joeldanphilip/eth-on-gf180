source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_clock_latency_trial.odb 4_clock_latency_trial.sdc
set_propagated_clock [all_clocks]
# Large delay cells have strongly asymmetric corner delays and caused the
# prior hold repair to overshoot setup. Test ordinary buffers for this trial.
set_dont_use [get_lib_cells */*__dly*]
set_dont_use [get_lib_cells */*_1]
estimate_parasitics -placement
repair_timing -setup -max_passes 50 -max_iterations 100 -repair_tns 100
detailed_placement
estimate_parasitics -placement
repair_timing -hold -allow_setup_violations -max_passes 100 -max_iterations 1000
detailed_placement
check_placement -verbose
estimate_parasitics -placement
write_db $::env(RESULTS_DIR)/4_balanced_no_drive1.odb
write_sdc $::env(RESULTS_DIR)/4_balanced_no_drive1.sdc
set physical_qor_stage balanced_no_drive1
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
