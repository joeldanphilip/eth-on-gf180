# Independent audit: the functional setup/hold run keeps its asynchronous
# clock groups. Remove those groups only in this process so real cross-domain
# datapaths can be bounded without inventing a synchronous phase relationship.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_final.odb 6_final.sdc
set_propagated_clock [all_clocks]
source /home/joelphilip/Documents/ethernet_formal/build/cdc_endpoints/endpoints.tcl
# The pinned binary advertises -all but lacks its backing C++ command.
# write_sdc serializes the one functional asynchronous group as group1.
unset_clock_groups -asynchronous -name group1
foreach row $cdc_crossings {
  lassign $row label source dest budget
  set from [get_cells -quiet $source]
  set to [get_pins -quiet $dest]
  if {[llength $from] != 1 || [llength $to] != 1} {
    error "Missing CDC endpoint $label: $source -> $dest"
  }
  set_max_delay $budget -ignore_clock_latency -from $from -to $to
}
set summary [open $::env(REPORTS_DIR)/extracted_cdc_slacks.csv w]
puts $summary "corner,crossing,budget_ns,slack_ns"
set failed 0
foreach corner {WC BC TC} {
  read_spef -corner $corner $::env(RESULTS_DIR)/6_${corner}.spef
  set report $::env(REPORTS_DIR)/extracted_${corner}_cdc.rpt
  set fd [open $report w]
  puts $fd "Independent CDC flight-time audit; conservative 8 ns datapath bounds."
  puts $fd "Includes source clock-to-Q and endpoint setup; ignores clock latencies."
  puts $fd "Gray bounds prevent overlap of successive transitions; handshake data is held pending acknowledgement."
  close $fd
  set worst 1e30
  foreach row $cdc_crossings {
    lassign $row label source dest budget
    set from [get_cells $source]
    set to [get_pins $dest]
    set paths [find_timing_paths -scenes [list $corner] -from $from -to $to \
      -path_delay max -group_path_count 1 -sort_by_slack]
    if {![llength $paths]} {error "Missing CDC timing path $corner $label"}
    set slack [get_property [lindex $paths 0] slack]
    puts $summary "$corner,$label,$budget,$slack"
    if {$slack < $worst} {set worst $slack}
    if {$slack < 0} {set failed 1}
    report_checks -scenes [list $corner] -from $from -to $to -path_delay max \
      -group_path_count 1 -format full_clock_expanded -fields {slew cap fanout} >> $report
  }
  puts "EXTRACTED_CDC $corner crossings=[llength $cdc_crossings] worst_slack=$worst"
}
close $summary
if {$failed} {error "CDC flight-time audit failed; see extracted_cdc_slacks.csv"}
