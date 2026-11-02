# Read-only endpoint/constraint sanity check using estimates, not signoff.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_1_grt.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]
estimate_parasitics -global_routing
source /home/joelphilip/Documents/ethernet_formal/build/cdc_endpoints/endpoints.tcl
unset_clock_groups -asynchronous -name group1
foreach row $cdc_crossings {
  lassign $row label source dest budget
  set from [get_cells -quiet $source]
  set to [get_pins -quiet $dest]
  if {[llength $from] != 1 || [llength $to] != 1} {error "Missing endpoint $label"}
  set_max_delay $budget -ignore_clock_latency -from $from -to $to
}
set worst 1e30
foreach row $cdc_crossings {
  lassign $row label source dest budget
  set paths [find_timing_paths -scenes WC -from [get_cells $source] -to [get_pins $dest] \
    -path_delay max -group_path_count 1 -sort_by_slack]
  if {![llength $paths]} {error "No estimated path $label"}
  set slack [get_property [lindex $paths 0] slack]
  if {$slack < $worst} {set worst $slack; set worst_label $label}
}
puts "CDC_ESTIMATE_SANITY crossings=[llength $cdc_crossings] worst=$worst_label slack=$worst NOT_EXTRACTED_SIGNOFF"
lassign [lindex $cdc_crossings 0] label source dest budget
report_checks -scenes WC -from [get_cells $source] -to [get_pins $dest] -path_delay max \
  -format full_clock_expanded -fields {slew cap fanout}
foreach name {VDD VSS} {
  set net [[ord::get_db_block] findNet $name]
  puts "POWER_PORT_AUDIT net=$name special=[$net isSpecial] ports=[llength [$net getBTerms]]"
}
