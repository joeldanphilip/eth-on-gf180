# Read-only placement audit for the split3 ECO checkpoint.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split3_route.odb 5_read_control_worst_buffer_split3.sdc
catch {check_placement -verbose} placement_rc
puts "SPLIT3_PLACEMENT_CHECK_RETURN $placement_rc"
set block [ord::get_db_block]
foreach name {place22442 clkload1793 read_control_net24870_local27482 read_control_net24870_pair27483 read_control_net24915_local27481 PHY_EDGE_ROW_1327_Right_1327} {
  set inst [$block findInst $name]
  if {$inst ne "NULL"} {
    set box [$inst getBBox]
    puts "SPLIT3_OVERLAP inst=$name master=[[$inst getMaster] getName] x=[$box xMin] y=[$box yMin] x2=[$box xMax] y2=[$box yMax]"
  }
}
puts "SPLIT3_PLACEMENT_AUDIT complete"
