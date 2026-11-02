# Bind PG pins created by antenna repair and filler placement, then verify
# every exposed standard-cell supply pin before extraction/export.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_route.odb 5_route.sdc
set block [ord::get_db_block]
global_connect
set checked 0
set bad 0
foreach inst [$block getInsts] {
  foreach term [$inst getITerms] {
    set kind [[$term getMTerm] getSigType]
    if {$kind ni {POWER GROUND}} {continue}
    incr checked
    set expected [expr {$kind eq "POWER" ? "VDD" : "VSS"}]
    set net [$term getNet]
    if {$net eq "NULL" || [$net getName] ne $expected || ![$net isSpecial]} {
      if {$bad < 10} {puts "ROUTE_POWER_BAD [$inst getName]/[[$term getMTerm] getName] expected=$expected"}
      incr bad
    }
  }
}
puts "ROUTE_POWER_AUDIT pins_checked=$checked remaining_bad=$bad"
if {$bad} {error "Unconnected or incorrectly bound physical power pins"}
write_db $::env(RESULTS_DIR)/5_route.odb
