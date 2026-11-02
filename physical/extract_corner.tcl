# Run in a fresh process for each GF180 RC rules file (CORNER=WC/BC/TC).
source $::env(SCRIPTS_DIR)/load.tcl
set stage 5_route
if {[info exists ::env(SIGNOFF_STAGE)]} {set stage $::env(SIGNOFF_STAGE)}
if {$stage ni {5_route 6_final}} {error "Unsupported extraction checkpoint $stage"}
load_design ${stage}.odb ${stage}.sdc
if {$stage eq "6_final" && [file mtime $::env(RESULTS_DIR)/6_final.odb] < [file mtime $::env(RESULTS_DIR)/5_route.odb]} {
  error "Final checkpoint predates the routed database; run eco-finish first"
}
if {![design_is_routed]} {error "Refusing extraction of an unrouted design"}
define_process_corner -ext_model_index 0 X
puts "PHYSICAL_EXTRACTION stage=$stage corner=$::env(CORNER) rules=$::env(RCX_RULES)"
extract_parasitics -ext_model_file $::env(RCX_RULES) -corner_cnt 1
write_spef $::env(RESULTS_DIR)/6_$::env(CORNER).spef
