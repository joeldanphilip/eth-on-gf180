# Rebuild global-route guides after localized cell replacement.  Cell sizing
# changes pin access, so stale guides are intentionally discarded first.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_sized.odb 5_read_control_sized.sdc
source /home/joelphilip/Documents/ethernet_formal/physical/eco_pre_grt.tcl
set_propagated_clock [all_clocks]
source $::env(FASTROUTE_TCL)
set_routing_layers -clock Metal4-Metal5
pin_access
set args [list -congestion_report_file $::env(REPORTS_DIR)/read_control_size_clean_grt_congestion.rpt]
lappend args -resistance_aware
if {[env_var_exists_and_non_empty GLOBAL_ROUTE_ARGS]} {
  set args [concat $::env(GLOBAL_ROUTE_ARGS) $args]
}
global_route {*}$args
if {![grt::have_routes]} {error "Clean guide rebuild produced no routes"}
orfs_write_db $::env(RESULTS_DIR)/5_read_control_sized_grt.odb
orfs_write_sdc $::env(RESULTS_DIR)/5_read_control_sized_grt.sdc
puts "READ_CONTROL_SIZE_CLEAN_GRT complete"
