# Bounded STA-feedback sizing experiment. Only same-family drive grades are tried.
set dir build/gf180_closure
if {[info exists ::env(RESIZE_PROFILE)]} {set dir $::env(RESIZE_PROFILE)}
set ::env(LIB_MAX) $dir/ss.lib
set ::env(LIB_MIN) $dir/ff.lib
set ::env(NETLIST) $dir/mac_hold.v
set ::env(HOLD_REPORT) $dir/resize_initial_hold.txt
set ::env(KEEP_OPEN) 1
source sta/timing.tcl
set libname [get_full_name [lindex [get_libs *ss*] 0]]
set accepted 0
set trials 0
set seconds 90
set rounds 30
set greedy 0
set exhaustive 0
set bidirectional 0
set side_loads 0
set target_slack 0
if {[info exists ::env(RESIZE_SIDE_LOADS)]} {set side_loads $::env(RESIZE_SIDE_LOADS)}
if {[info exists ::env(RESIZE_TARGET_NS)]} {set target_slack $::env(RESIZE_TARGET_NS)}
if {[info exists ::env(RESIZE_EXHAUSTIVE)]} {set exhaustive $::env(RESIZE_EXHAUSTIVE)}
if {[info exists ::env(RESIZE_BIDIRECTIONAL)]} {set bidirectional $::env(RESIZE_BIDIRECTIONAL)}
if {[info exists ::env(RESIZE_SECONDS)]} {set seconds $::env(RESIZE_SECONDS)}
if {[info exists ::env(RESIZE_ROUNDS)]} {set rounds $::env(RESIZE_ROUNDS)}
if {[info exists ::env(RESIZE_GREEDY)]} {set greedy $::env(RESIZE_GREEDY)}
set deadline [expr {[clock seconds]+$seconds}]
for {set round 0} {$round<$rounds && [clock seconds]<$deadline} {incr round} {
    set oldwns [sta::worst_slack -max]
    set oldtns [sta::total_negative_slack -max]
    if {$oldwns>=$target_slack} {break}
    set instances {}
    set ordered_paths {}
    foreach path [find_timing_paths -path_delay max -slack_max $target_slack -group_path_count 1] {
        lappend ordered_paths [list [get_property $path slack] $path]
    }
    if {$side_loads} {
        foreach entry [lsort -real -index 0 $ordered_paths] {
            foreach point [get_property [lindex $entry 1] points] {
                foreach cell [get_fanout -from [get_property $point pin] -pin_levels 1 -only_cells -flat] {
                    set instance [get_full_name $cell]
                    if {[lsearch -exact $instances $instance]<0} {lappend instances $instance}
                }
            }
        }
    }
    foreach entry [lsort -real -index 0 $ordered_paths] {
        set path [lindex $entry 1]
        foreach point [get_property $path points] {
            set name [get_full_name [get_property $point pin]]
            set slash [string last / $name]
            if {$slash>=0} {
                set instance [string range $name 0 [expr {$slash-1}]]
                if {[lsearch -exact $instances $instance]<0} {lappend instances $instance}
            }
        }
    }
    set bestwns $oldwns
    set besttns $oldtns
    set best {}
    if {!$greedy} {set instances [lsort -unique $instances]}
    foreach instance $instances {
        if {[clock seconds]>=$deadline} {break}
        set cell [lindex [get_cells $instance] 0]
        set oldref [get_property $cell ref_name]
        if {![regexp {^(.*_)([0-9]+)$} $oldref unused stem drive]} {continue}
        set sizes {2 3 4 8 12 16 20}
        if {$bidirectional} {set sizes {1 2 3 4 8 12 16 20}}
        if {!$bidirectional && !$exhaustive && $greedy && [regexp {__(clkbuf|buf)_[0-9]+$} $oldref]} {set sizes {8 12 16 20}}
        foreach size $sizes {
            if {$size==$drive || (!$bidirectional && $size<$drive)} {continue}
            set replacement ${stem}${size}
            set libcells [get_lib_cells -quiet $libname/$replacement]
            if {[llength $libcells]==0} {continue}
            if {![replace_cell $instance [lindex $libcells 0]]} {continue}
            incr trials
            set newwns [sta::worst_slack -max]
            set newtns [sta::total_negative_slack -max]
            set hold [sta::worst_slack -min]
            if {$hold>=0 && ($newwns>$bestwns+0.00001 || (abs($newwns-$bestwns)<0.00001 && $newtns>$besttns+0.0001))} {
                set best [list $instance $oldref $replacement]
                set bestwns $newwns
                set besttns $newtns
            }
            if {![replace_cell $instance [lindex [get_lib_cells $libname/$oldref] 0]]} {error "rollback failed"}
            if {!$exhaustive} {break}
        }
        if {$greedy && [llength $best]>0} {break}
    }
    if {[llength $best]==0} {puts "SIZING no improving candidate"; break}
    lassign $best instance oldref replacement
    if {![replace_cell $instance [lindex [get_lib_cells $libname/$replacement] 0]]} {error "commit failed"}
    incr accepted
    puts "SIZING round=$round $instance $oldref -> $replacement setup_ns=$bestwns tns_ns=$besttns"
    flush stdout
}
puts "SIZING complete accepted=$accepted trials=$trials"
report_worst_slack -max -digits 4
report_worst_slack -min -digits 4
report_tns
write_verilog $dir/mac_resized_opensta_raw.v
exit
