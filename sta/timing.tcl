# Pre-layout single typical corner, without extracted interconnect or CTS.
set typical tools/ORFS/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib
if {[info exists ::env(LIB_MAX)] && [info exists ::env(LIB_MIN)]} {
    # Libraries must contain compatible cell names/pin functions with mapping.
    if {$::env(LIB_MAX) eq $::env(LIB_MIN)} {
        read_liberty $::env(LIB_MAX)
    } else {
        read_liberty -max $::env(LIB_MAX)
        read_liberty -min $::env(LIB_MIN)
    }
    puts "Timing libraries: max=$::env(LIB_MAX) min=$::env(LIB_MIN)"
} else {
    read_liberty $typical
    puts "Timing library: Nangate45 typical (single-corner estimate)"
}
set netlist build/mac_mapped.v
if {[info exists ::env(NETLIST)]} {set netlist $::env(NETLIST)}
read_verilog $netlist
link_design eth_mac_1g_fifo
read_sdc sta/mac.sdc
check_setup -verbose
report_checks -path_delay max -group_path_count 5 -format full_clock_expanded -fields {slew cap fanout}
report_checks -path_delay min -group_path_count 5 -format full_clock_expanded -fields {slew cap fanout}
report_check_types -max_slew -max_capacitance -violators
report_worst_slack -max -digits 4
report_worst_slack -min -digits 4
report_tns
set hold_report build/hold_endpoints.txt
if {[info exists ::env(HOLD_REPORT)]} {set hold_report $::env(HOLD_REPORT)}
set out [open $hold_report w]
foreach path [find_timing_paths -path_delay min -slack_max 0.0 -group_path_count 100000] {
    puts $out [get_full_name [get_property $path endpoint]]
}
close $out
if {![info exists ::env(KEEP_OPEN)]} {exit}
