# Finish the localized read-control ECO without replacing the clean 5_route DB.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split7_route.odb 5_read_control_worst_buffer_split7_legalized.sdc

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
    if {$net eq "NULL" || [$net getName] ne $expected || ![$net isSpecial]} {
      if {$bad < 10} {puts "READ_CONTROL_FINAL_POWER_BAD [$inst getName]/[[$term getMTerm] getName] expected=$expected"}
      incr bad
    }
  }
}
puts "READ_CONTROL_FINAL_POWER_AUDIT pins_checked=$checked remaining_bad=$bad"
if {$bad} {error "Candidate power connectivity audit failed"}

if {[info exists ::env(FILL_CELLS)] && $::env(FILL_CELLS) ne ""} {
  filler_placement $::env(FILL_CELLS)
  check_placement
}

orfs_write_db $::env(RESULTS_DIR)/6_read_control_fill.odb
write_sdc $::env(RESULTS_DIR)/6_read_control_fill.sdc
puts "READ_CONTROL_FINAL_FILL complete"
