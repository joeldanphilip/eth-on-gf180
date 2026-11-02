source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_empty_eco_repaired.odb 4_empty_eco_repaired.sdc
set_propagated_clock [all_clocks]
# Latest report: 10 loads, 0.17 pF and 1.59 ns WC slew on this buffer.
replace_cell place17696 gf180mcu_fd_sc_mcu9t5v0__buf_8
detailed_placement
check_placement -verbose
estimate_parasitics -placement
set physical_qor_stage empty_eco_final
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
write_db $::env(RESULTS_DIR)/4_empty_eco_final.odb
write_sdc $::env(RESULTS_DIR)/4_empty_eco_final.sdc
