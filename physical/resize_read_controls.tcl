# Localized drive-strength ECO for the registered bank-select/read-mux cone.
# Only cells in the generated cone manifest are eligible for replacement.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_2_route.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]
global_connect
source $::env(FASTROUTE_TCL)
set_routing_layers -clock Metal4-Metal5
if {![grt::have_routes]} {error "Missing saved route guides"}
set block [ord::get_db_block]

set manifest /home/joelphilip/Documents/ethernet_formal/build/read_control_cone/read_control_cone.tcl
source $manifest
set counts [dict create]
foreach row $read_control_cells {
  set iname [lindex $row 0]
  set inst [$block findInst $iname]
  if {$inst eq "NULL"} {error "Manifest cell missing: $iname"}
  set master [[$inst getMaster] getName]
  set replacement ""
  switch -- $master {
    gf180mcu_fd_sc_mcu9t5v0__aoi222_2 {set replacement gf180mcu_fd_sc_mcu9t5v0__aoi222_4}
    gf180mcu_fd_sc_mcu9t5v0__and4_2   {set replacement gf180mcu_fd_sc_mcu9t5v0__and4_4}
    gf180mcu_fd_sc_mcu9t5v0__nand3_2  {set replacement gf180mcu_fd_sc_mcu9t5v0__nand3_4}
  }
  if {$replacement ne ""} {
    replace_cell $iname $replacement
    dict incr counts $master
  }
}
set total 0
dict for {master count} $counts {incr total $count}
if {$total < 300} {error "Unexpectedly few mux gate replacements: $total"}
puts "READ_CONTROL_SIZE_ECO replaced=$total counts=$counts"

global_route -start_incremental
detailed_placement -incremental
check_placement -verbose
global_route -end_incremental -resistance_aware \
  -congestion_report_file $::env(REPORTS_DIR)/read_control_size_congestion.rpt
set physical_qor_stage read_control_size_eco
source /home/joelphilip/Documents/ethernet_formal/physical/qor.tcl
write_db $::env(RESULTS_DIR)/5_read_control_sized.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_sized.sdc
