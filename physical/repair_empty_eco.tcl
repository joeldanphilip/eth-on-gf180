source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_carry_eco.odb 4_carry_eco.sdc
set_propagated_clock [all_clocks]
set_dont_use $::env(DONT_USE_CELLS)
# This buffer now fans out to the balanced carry tree.  Its observed WC
# slew is 0.78 ns at 0.08 pF; isolate that load before setup optimization.
replace_cell place17697 gf180mcu_fd_sc_mcu9t5v0__buf_8
estimate_parasitics -placement
repair_timing -setup -setup_margin 0.10 -repair_tns 100 -max_passes 100 -max_iterations 300
detailed_placement
estimate_parasitics -placement
repair_timing -hold -hold_margin 0.03 -max_passes 50 -max_iterations 300
detailed_placement
check_placement -verbose
estimate_parasitics -placement
set physical_qor_stage empty_eco_repaired
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
write_db $::env(RESULTS_DIR)/4_empty_eco_repaired.odb
write_sdc $::env(RESULTS_DIR)/4_empty_eco_repaired.sdc
