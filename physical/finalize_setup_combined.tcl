source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_setup_combined_resize_route.odb 5_setup_combined_resize_legalized.sdc
set_propagated_clock [all_clocks]
global_connect
set block [ord::get_db_block]
set checked 0
set bad 0
foreach inst [$block getInsts] {
  foreach term [$inst getITerms] {
    set kind [[$term getMTerm] getSigType]
    if {$kind ni {POWER GROUND}} {continue}
    incr checked
    set expected [expr {$kind eq "POWER" ? "VDD" : "VSS"}]
    set net [$term getNet]
    if {$net eq "NULL" || [$net getName] ne $expected || ![$net isSpecial]} {incr bad}
  }
}
puts "SETUP_COMBINED_POWER_AUDIT pins_checked=$checked remaining_bad=$bad"
if {$bad} {error "Combined setup ECO power audit failed"}
if {[info exists ::env(FILL_CELLS)] && $::env(FILL_CELLS) ne ""} {
  filler_placement $::env(FILL_CELLS)
  check_placement
}
orfs_write_db $::env(RESULTS_DIR)/6_setup_combined_fill.odb
write_sdc $::env(RESULTS_DIR)/6_setup_combined_fill.sdc
puts "SETUP_COMBINED_FILL complete"
