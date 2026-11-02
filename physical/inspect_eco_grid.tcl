source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_1_grt.odb 5_1_grt.sdc
set grid [[ord::get_db_block] getGCellGrid]
foreach method {getGridX getGridY getNumGridPatternsX getNumGridPatternsY} {
  if {[catch {$grid $method} result]} {puts "GRID_API $method $result"} else {
    puts "GRID_API $method count=[llength $result] first=[lrange $result 0 3] last=[lrange $result end-3 end]"
  }
}
foreach net [[ord::get_db_block] getNets] {
  set guides [$net getGuides]
  if {![llength $guides]} {continue}
  set guide [lindex $guides 0]
  set rect [$guide getBox]
  puts "GUIDE_EXAMPLE net=[$net getName] layer=[[$guide getLayer] getName] rect=$rect"
  puts "GUIDE_BOUNDS [$rect xMin] [$rect yMin] [$rect xMax] [$rect yMax]"
  break
}
