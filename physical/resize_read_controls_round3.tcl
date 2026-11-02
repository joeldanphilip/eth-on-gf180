# Third localized drive ECO for the remaining long-buffer and NAND4/NAND2 arcs.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_round2_signoff_route_jumper.odb 5_read_control_round2_sized.sdc
set_propagated_clock [all_clocks]
global_connect
set block [ord::get_db_block]
source /home/joelphilip/Documents/ethernet_formal/build/read_control_cone/read_control_cone.tcl
set counts [dict create]
foreach row $read_control_cells {
  set iname [lindex $row 0]
  set inst [$block findInst $iname]
  if {$inst eq "NULL"} {error "Manifest cell missing: $iname"}
  set master [[$inst getMaster] getName]
  set replacement ""
  switch -- $master {
    gf180mcu_fd_sc_mcu9t5v0__buf_12   {set replacement gf180mcu_fd_sc_mcu9t5v0__buf_20}
    gf180mcu_fd_sc_mcu9t5v0__nand2_2  {set replacement gf180mcu_fd_sc_mcu9t5v0__nand2_4}
    gf180mcu_fd_sc_mcu9t5v0__nand4_2  {set replacement gf180mcu_fd_sc_mcu9t5v0__nand4_4}
  }
  if {$replacement ne ""} {
    replace_cell $iname $replacement
    dict incr counts $master
  }
}
set total 0
dict for {master count} $counts {incr total $count}
if {$total < 300} {error "Unexpectedly few third-pass replacements: $total"}
puts "READ_CONTROL_SIZE_ECO_ROUND3 replaced=$total counts=$counts"
detailed_placement -incremental
check_placement -verbose
write_db $::env(RESULTS_DIR)/5_read_control_round3_sized.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_round3_sized.sdc
puts "READ_CONTROL_SIZE_ECO_ROUND3 complete"
