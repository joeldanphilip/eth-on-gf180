source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_output_buffer_eco.odb 4_cts.sdc
set_propagated_clock [all_clocks]
estimate_parasitics -placement
# Run hold independently: a setup loop can otherwise prevent hold repair.
help repair_timing
# Existing setup violations otherwise prevent necessary input hold buffers.
# This experiment permits setup regressions, which are measured below; it
# does not relax the SDC or imply either setup or hold closure.
repair_timing -hold -allow_setup_violations -max_iterations 1000 -max_passes 100
detailed_placement
check_placement -verbose
estimate_parasitics -placement
write_db $::env(RESULTS_DIR)/4_hold_repaired.odb
write_sdc $::env(RESULTS_DIR)/4_hold_repaired.sdc
set physical_qor_stage hold_repaired
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
