# Split only the four worst extracted TC slew loads.  This is a lower-congestion
# branch from the signed-off split7 route; the 14-load branch is retained as a
# diagnostic artifact but is not used as a signoff candidate.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_split7_route.odb 5_read_control_worst_buffer_split7_legalized.sdc
set_propagated_clock [all_clocks]
set targets {
  _193966_/B2 _193941_/C2 _193983_/B2 _193892_/B2
}
set n 0
foreach target $targets {
  set pins [get_pins $target]
  if {[llength $pins] != 1} {puts "TOP_ELECTRICAL_SMALL_SPLIT skip=$target pins=[llength $pins]"; continue}
  set inst_name [lindex [split $target /] 0]
  set inst [[ord::get_db_block] findInst $inst_name]
  if {$inst eq "NULL"} {puts "TOP_ELECTRICAL_SMALL_SPLIT skip=$target missing_instance"; continue}
  set box [$inst getBBox]
  set x [expr {[$box xMin] - 70000}]
  set y [$box yMin]
  set cell_name [format "read_control_electrical_small_split_%02d" $n]
  set net_name [format "read_control_electrical_small_net_%02d" $n]
  if {[catch {insert_buffer -buffer_cell gf180mcu_fd_sc_mcu9t5v0__buf_20 \
      -load_pins $pins -location [list $x $y] \
      -buffer_name $cell_name -net_name $net_name} msg]} {
    puts "TOP_ELECTRICAL_SMALL_SPLIT fail=$target error=$msg"
  } else {
    puts "TOP_ELECTRICAL_SMALL_SPLIT inserted=$target cell=$cell_name x=$x y=$y"
    incr n
  }
}
puts "TOP_ELECTRICAL_SMALL_SPLIT count=$n"
write_db $::env(RESULTS_DIR)/5_read_control_top_electrical_small_split.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_top_electrical_small_split.sdc
