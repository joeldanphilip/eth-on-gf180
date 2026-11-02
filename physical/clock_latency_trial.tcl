source $::env(SCRIPTS_DIR)/load.tcl
load_design 3_place.odb 3_place.sdc
repair_clock_inverters
clock_tree_synthesis -sink_clustering_enable -repair_clock_nets \
  -buf_list {gf180mcu_fd_sc_mcu9t5v0__clkbuf_8 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16 gf180mcu_fd_sc_mcu9t5v0__clkbuf_20} \
  -sink_clustering_size 64 -sink_clustering_max_diameter 200
set_propagated_clock [all_clocks]
foreach inst [[ord::get_db_block] getInsts] {
  if {[string match output* [$inst getName]] && [string match *__dlyb_* [[$inst getMaster] getName]]} {
    replace_cell [$inst getName] gf180mcu_fd_sc_mcu9t5v0__buf_16
  }
}
detailed_placement
check_placement -verbose
estimate_parasitics -placement
write_db $::env(RESULTS_DIR)/4_clock_latency_trial.odb
write_sdc $::env(RESULTS_DIR)/4_clock_latency_trial.sdc
set physical_qor_stage clock_latency_trial
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
