source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_setup_place24936_final.odb 6_setup_place24936_final.sdc
set_propagated_clock [all_clocks]
set summary [open $::env(REPORTS_DIR)/setup_place24936_extracted_corner_slacks.csv w]
puts $summary "corner,check,slack_ns"
set failed 0
foreach corner {WC BC TC} {
  read_spef -corner $corner $::env(RESULTS_DIR)/6_setup_place24936_$corner.spef
  set path $::env(REPORTS_DIR)/setup_place24936_extracted_${corner}_timing.rpt
  report_checks -scenes [list $corner] -path_delay min_max -group_path_count 5 -format full_clock_expanded -fields {slew cap fanout} > $path
  foreach kind {min max} {
    set paths [find_timing_paths -scenes [list $corner] -path_delay $kind -group_path_count 1 -sort_by_slack]
    if {![llength $paths]} {error "No constrained $kind timing paths in $corner"}
    set worst 1e30
    foreach timing_path $paths {
      set slack [get_property $timing_path slack]
      if {$slack < $worst} {set worst $slack}
    }
    puts $summary "$corner,$kind,$worst"
    puts "SETUP_ECO_EXTRACTED_SLACK corner=$corner check=$kind slack=$worst"
    if {$worst < 0} {set failed 1}
  }
  set electrical $::env(REPORTS_DIR)/setup_place24936_extracted_${corner}_electrical.rpt
  report_check_types -scenes [list $corner] -max_slew -max_capacitance -violators -max_count 20 -digits 9 > $electrical
  set efd [open $electrical r]
  set violations [regexp {\(VIOLATED\)} [read $efd]]
  close $efd
  puts "SETUP_ECO_EXTRACTED_ELECTRICAL corner=$corner has_violations=$violations"
  if {$violations} {set failed 1}
}
close $summary
set slew_slack [sta::max_slew_check_slack]
set cap_slack [sta::max_capacitance_check_slack]
puts "SETUP_ECO_EXTRACTED_ELECTRICAL_SLACK max_slew=$slew_slack max_capacitance=$cap_slack"
if {$slew_slack < 0 || $cap_slack < 0} {set failed 1}
if {$failed} {error "Setup ECO extracted closure failed"}
puts "SETUP_ECO_EXTRACTED_CHECK complete"
