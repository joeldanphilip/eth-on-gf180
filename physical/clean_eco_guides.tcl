source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_1_grt.odb 5_1_grt.sdc
global_connect
set block [ord::get_db_block]
set removed 0
set guides_removed 0
foreach net [$block getNets] {
  if {![llength [$net getITerms]] && ![llength [$net getBTerms]] && ![$net isSpecial]} {
    incr guides_removed [llength [$net getGuides]]
    puts "ECO_ORPHAN_NET_REMOVE [$net getName] guides=[llength [$net getGuides]]"
    odb::dbNet_destroy $net
    incr removed
  }
}
# Match GuideProcessor::isValidGuideLayerNum and frBlock::getGCellIdx in
# OpenROAD 08f67ee5ec: Metal1 pin access is legal within a single GCell.
# The last GCell extends to the die boundary and indices must be clamped.
set grid [$block getGCellGrid]
if {$grid eq "NULL"} {error "Missing global-routing grid"}
set gx [$grid getGridX]
set gy [$grid getGridY]
if {[llength $gx] < 2 || [llength $gy] < 2} {error "Invalid routing grid"}
set ox [lindex $gx 0]
set oy [lindex $gy 0]
set sx [expr {[lindex $gx 1] - $ox}]
set sy [expr {[lindex $gy 1] - $oy}]
set nx [llength $gx]
set ny [llength $gy]
proc eco_gcell_index {coord origin spacing count} {
  return [expr {min(max(($coord - $origin) / $spacing, 0), $count - 1)}]
}
set bad 0
set access_guides 0
foreach net [$block getNets] {
  foreach guide [$net getGuides] {
    set layer [[$guide getLayer] getName]
    set valid [expr {$layer in {Metal2 Metal3 Metal4 Metal5}}]
    if {$layer eq "Metal1"} {
      set r [$guide getBox]
      # DRT shrinks the rectangle by one DBU before comparing its corners.
      set xl [eco_gcell_index [expr {[$r xMin] + 1}] $ox $sx $nx]
      set xh [eco_gcell_index [expr {[$r xMax] - 1}] $ox $sx $nx]
      set yl [eco_gcell_index [expr {[$r yMin] + 1}] $oy $sy $ny]
      set yh [eco_gcell_index [expr {[$r yMax] - 1}] $oy $sy $ny]
      set valid [expr {$xl == $xh && $yl == $yh}]
      if {$valid} {incr access_guides}
    }
    if {!$valid} {
      if {$bad < 10} {puts "ECO_GUIDE_OUT_OF_RANGE net=[$net getName] layer=$layer"}
      incr bad
    }
  }
}
puts "ECO_GUIDE_AUDIT orphan_nets_removed=$removed orphan_guides_removed=$guides_removed legal_pin_access_guides=$access_guides active_bad_guides=$bad"
if {$bad} {error "Active guides require rerouting; refusing to mask the inconsistency"}
write_db $::env(RESULTS_DIR)/5_1_grt.odb
