# Read-only extraction of the physical RX empty-flag combinational cone.
source $::env(SCRIPTS_DIR)/load.tcl
if {[info exists ::tx_reduce]} {
  load_design 4_empty_eco_final.odb 4_empty_eco_final.sdc
} else {
  if {[file exists $::env(RESULTS_DIR)/5_1_grt_before_empty_eco.odb]} {
    load_design 5_1_grt_before_empty_eco.odb 5_1_grt_before_empty_eco.sdc
  } else {
    load_design 5_1_grt.odb 5_1_grt.sdc
  }
}
set block [ord::get_db_block]
set outdir /home/joelphilip/Documents/ethernet_formal/build/empty_eco
file mkdir $outdir
set endpoint [$block findInst _380055_]
set advance [$block findInst _278952_]
set reset [$block findInst _424531_]
set commit_sel [$block findInst _279000_]
foreach obj [list $endpoint $advance $reset] {
  if {$obj eq "NULL"} {error "Expected RX empty cone instance missing"}
}
set root [[$endpoint findITerm D] getNet]
set cut_a [[$advance findITerm ZN] getNet]
set cut_r [[$reset findITerm Q] getNet]
set cut_c [[$commit_sel findITerm ZN] getNet]
set cuts [list [$cut_a getName] [$cut_r getName] [$cut_c getName]]
if {[info exists ::tx_reduce]} {
  set endpoint [$block findInst _397888_]
  set root [[$endpoint findITerm D] getNet]
  set cuts {}
  set outdir /home/joelphilip/Documents/ethernet_formal/build/tx_reduction
  file mkdir $outdir
}
set fd [open $outdir/cone.tsv w]
puts $fd [join [list ROOT [$root getName] [$endpoint getName] D] "\t"]
puts $fd [join [list CUT advance [$cut_a getName]] "\t"]
puts $fd [join [list CUT reset [$cut_r getName]] "\t"]
puts $fd [join [list CUT commit [$cut_c getName]] "\t"]
set queue [list $root]
set seen_nets [dict create]
set seen_cells [dict create]
while {[llength $queue]} {
  set net [lindex $queue 0]
  set queue [lrange $queue 1 end]
  set name [$net getName]
  if {[dict exists $seen_nets $name]} {continue}
  dict set seen_nets $name 1
  set drivers {}
  foreach term [$net getITerms] {
    if {[[$term getMTerm] getIoType] eq "OUTPUT"} {lappend drivers $term}
  }
  set is_port 0
  foreach term [$net getBTerms] {
    if {[$term getIoType] eq "INPUT"} {set is_port 1}
  }
  if {$is_port && ![llength $drivers]} {
    puts $fd [join [list LEAF $name PORT] "\t"]
    continue
  }
  if {[llength $drivers] != 1} {error "Expected one driver for $name"}
  set inst [[lindex $drivers 0] getInst]
  set master [[$inst getMaster] getName]
  if {$name in $cuts || [regexp {__(dff|lat)} $master]} {
    puts $fd [join [list LEAF $name [$inst getName]] "\t"]
    continue
  }
  set iname [$inst getName]
  if {[dict exists $seen_cells $iname]} {continue}
  dict set seen_cells $iname 1
  puts $fd [join [list CELL $iname $master {*}[$inst getLocation]] "\t"]
  foreach term [$inst getITerms] {
    set mt [$term getMTerm]
    if {[$mt getSigType] in {POWER GROUND}} {continue}
    set pnet [$term getNet]
    if {$pnet eq "NULL"} {error "Unconnected signal $iname/[$mt getName]"}
    puts $fd [join [list PIN $iname [$mt getName] [$mt getIoType] [$pnet getName]] "\t"]
    if {[$mt getIoType] eq "INPUT"} {lappend queue $pnet}
  }
}
close $fd
puts "EMPTY_CONE cells=[dict size $seen_cells] nets=[dict size $seen_nets] file=$outdir/cone.tsv"
