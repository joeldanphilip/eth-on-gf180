source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_empty_eco.odb 4_empty_eco.sdc
set_propagated_clock [all_clocks]
source /home/joelphilip/Documents/ethernet_formal/build/carry_eco/insert.tcl
detailed_placement
check_placement -verbose
estimate_parasitics -placement
set physical_qor_stage carry_eco
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
write_db $::env(RESULTS_DIR)/4_carry_eco.odb
write_sdc $::env(RESULTS_DIR)/4_carry_eco.sdc
