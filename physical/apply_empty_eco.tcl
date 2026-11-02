source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_1_grt.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]
set eco_dir /home/joelphilip/Documents/ethernet_formal/build/empty_eco
if {![file exists $eco_dir/manifest.json]} {error "Run both ECO SAT proofs first"}
if {![file exists $::env(REPORTS_DIR)/physical_empty_eco_before_timing.rpt]} {
  estimate_parasitics -placement
  set physical_qor_stage empty_eco_before
  source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
}
source $eco_dir/insert.tcl
detailed_placement
check_placement -verbose
estimate_parasitics -placement
set physical_qor_stage empty_eco_after
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
write_db $::env(RESULTS_DIR)/4_empty_eco.odb
write_sdc $::env(RESULTS_DIR)/4_empty_eco.sdc
