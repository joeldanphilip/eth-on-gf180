# Experimental candidate: move the newly dominant bank-select buffer beside its AOI load.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_moved_route.odb 5_read_control_worst_buffer_moved.sdc
set block [ord::get_db_block]
set inst [$block findInst place22445]
if {$inst eq "NULL"} {error "place22445 missing"}
puts "MOVE_SECOND_WORST old_bbox=[[$inst getBBox] xMin],[[$inst getBBox] yMin]"
if {[catch {$inst setLocation 7716800 2499840} msg]} {error "setLocation failed: $msg"}
if {[catch {$inst setPlacementStatus PLACED} msg]} {error "setPlacementStatus failed: $msg"}
puts "MOVE_SECOND_WORST new_bbox=[[$inst getBBox] xMin],[[$inst getBBox] yMin]"
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_moved2.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_moved2.sdc
puts "MOVE_SECOND_WORST complete"
