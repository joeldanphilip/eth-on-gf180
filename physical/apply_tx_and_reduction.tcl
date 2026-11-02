source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_tx_reduction.odb 4_tx_reduction.sdc
set_propagated_clock [all_clocks]
source /home/joelphilip/Documents/ethernet_formal/build/tx_and_reduction/insert.tcl
detailed_placement
check_placement -verbose
estimate_parasitics -placement
set physical_qor_stage tx_and_reduction
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
write_db $::env(RESULTS_DIR)/4_tx_and_reduction.odb
write_sdc $::env(RESULTS_DIR)/4_tx_and_reduction.sdc
