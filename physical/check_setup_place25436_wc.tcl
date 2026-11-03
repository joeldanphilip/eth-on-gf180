source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_setup_place25436_final.odb 6_setup_place25436_final.sdc
read_spef -corner WC $::env(RESULTS_DIR)/6_setup_place25436_WC.spef
set paths [find_timing_paths -scenes {WC} -path_delay max -group_path_count 1 -sort_by_slack]
if {![llength $paths]} {error "No WC setup path"}
set worst [get_property [lindex $paths 0] slack]
puts "SETUP_ECO_25436_WC_SETUP_SLACK slack=$worst"
report_checks -scenes {WC} -path_delay max -group_path_count 5 -format full_clock_expanded > $::env(REPORTS_DIR)/setup_place25436_WC_timing.rpt
