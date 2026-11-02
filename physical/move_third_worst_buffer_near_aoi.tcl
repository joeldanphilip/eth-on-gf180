# Experimental candidate: move the newly dominant RX bank-select buffer beside its AOI load.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_moved2_route.odb 5_read_control_worst_buffer_moved2.sdc
set block [ord::get_db_block]
set inst [$block findInst place24939]
if {$inst eq "NULL"} {error "place24939 missing"}
puts "MOVE_THIRD_WORST old_bbox=[[$inst getBBox] xMin],[[$inst getBBox] yMin]"
if {[catch {$inst setLocation 1706880 12216960} msg]} {error "setLocation failed: $msg"}
if {[catch {$inst setPlacementStatus PLACED} msg]} {error "setPlacementStatus failed: $msg"}
puts "MOVE_THIRD_WORST new_bbox=[[$inst getBBox] xMin],[[$inst getBBox] yMin]"
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_moved3.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_moved3.sdc
puts "MOVE_THIRD_WORST complete"
