# Read-only audit of the registered bank-select -> read-data mux cones.
# This deliberately stops at the first sequential endpoint and emits a Tcl
# manifest for a later localized repair.  It does not modify or save the DB.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_2_route.odb 5_1_grt.sdc
set block [ord::get_db_block]
set outdir /home/joelphilip/Documents/ethernet_formal/build/read_control_cone
file mkdir $outdir

proc is_seq_master {master} {
  # GF180 mapped sequential masters used by this design are dffq*/sdff*.
  return [regexp {__(s?dff|dffq)} $master]
}

set seeds {}
foreach domain {rx tx} {
  for {set bit 0} {$bit < 16} {incr bit} {
    set name "${domain}_fifo.fifo_inst.bank_select_onehot_reg\[$bit\]"
    set net [$block findNet $name]
    if {$net eq "NULL"} {error "Missing bank-select seed net $name"}
    lappend seeds [list $domain $bit $net]
  }
}

set seen_nets [dict create]
set seen_cells [dict create]
set captures [dict create]
set other_seq [dict create]
set queue {}
foreach row $seeds {lappend queue [lindex $row 2]}

while {[llength $queue]} {
  set net [lindex $queue 0]
  set queue [lrange $queue 1 end]
  if {$net eq "NULL"} {continue}
  set nname [$net getName]
  if {[dict exists $seen_nets $nname]} {continue}
  dict set seen_nets $nname 1

  foreach term [$net getITerms] {
    set mt [$term getMTerm]
    if {[$mt getIoType] ne "INPUT"} {continue}
    set inst [$term getInst]
    set iname [$inst getName]
    set master [[$inst getMaster] getName]
    set pin [$mt getName]

    if {[is_seq_master $master]} {
      # Only data captures in the physical read mux are allowed endpoints.
      if {$pin ne "D"} {continue}
      set qname ""
      foreach qterm [$inst getITerms] {
        set qmt [$qterm getMTerm]
        if {[$qmt getIoType] eq "OUTPUT" && [$qterm getNet] ne "NULL"} {
          if {[$qmt getName] eq "Q" || $qname eq ""} {
            set qname [[$qterm getNet] getName]
          }
        }
      }
      if {[regexp {^(rx|tx)_fifo\.fifo_inst\.group_read_data} $qname]} {
        dict set captures $iname [list $nname $pin $master $qname]
      } else {
        # A control cone may feed another state element through a shared
        # decode term.  Record and stop here; never optimize through it.
        dict set other_seq $iname [list $nname $pin $master $qname]
      }
      continue
    }

    if {[dict exists $seen_cells $iname]} {continue}
    dict set seen_cells $iname [list $master $nname]
    foreach out [$inst getITerms] {
      set omt [$out getMTerm]
      if {[$omt getIoType] ne "OUTPUT"} {continue}
      set onet [$out getNet]
      if {$onet ne "NULL"} {lappend queue $onet}
    }
  }
}

set seed_count [llength $seeds]
set net_count [dict size $seen_nets]
set cell_count [dict size $seen_cells]
set capture_count [dict size $captures]
if {$capture_count < 1 || $capture_count > 512} {
  error "Unexpected read-control capture count $capture_count"
}
if {$cell_count > 20000} {error "Read-control cone too large: $cell_count cells"}

set fd [open $outdir/read_control_cone.tcl w]
puts $fd "# Generated read-only manifest from 5_2_route.odb"
puts $fd {set read_control_seeds {}}
foreach row $seeds {
  lassign $row domain bit net
  puts $fd [list lappend read_control_seeds [list $domain $bit [$net getName]]]
}
puts $fd {set read_control_cells {}}
dict for {iname row} $seen_cells {
  puts $fd [list lappend read_control_cells [list $iname [lindex $row 0]]]
}
puts $fd {set read_control_nets {}}
dict for {nname unused} $seen_nets {
  puts $fd [list lappend read_control_nets $nname]
}
puts $fd {set read_control_captures {}}
dict for {iname row} $captures {
  puts $fd [list lappend read_control_captures [list $iname [lindex $row 0] [lindex $row 1] [lindex $row 2] [lindex $row 3]]]
}
puts $fd {set read_control_other_sequential {}}
dict for {iname row} $other_seq {
  puts $fd [list lappend read_control_other_sequential [list $iname [lindex $row 0] [lindex $row 1] [lindex $row 2] [lindex $row 3]]]
}
close $fd

set report [open $outdir/read_control_cone.tsv w]
puts $report "kind\tname\tvalue"
dict for {iname row} $captures {
  puts $report [join [list CAPTURE $iname [join $row ":"]] "\t"]
}
dict for {iname row} $seen_cells {
  puts $report [join [list CELL $iname [join $row ":"]] "\t"]
}
close $report

puts "READ_CONTROL_CONE seeds=$seed_count nets=$net_count cells=$cell_count captures=$capture_count other_sequential=[dict size $other_seq] manifest=$outdir/read_control_cone.tcl"
