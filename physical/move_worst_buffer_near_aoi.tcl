# Experimental candidate: move the long-read-path buffer next to its AOI load.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_read_control_worst_buffer_fixedsite_route.odb 5_read_control_worst_buffer_fixedsite.sdc
set block [ord::get_db_block]
set inst [$block findInst place22442]
if {$inst eq "NULL"} {error "place22442 missing"}
puts "MOVE_WORST_BUFFER old_bbox=[[$inst getBBox] xMin],[[$inst getBBox] yMin]"
if {[catch {$inst setLocation 8979040 12620160} msg]} {error "setLocation failed: $msg"}
if {[catch {$inst setPlacementStatus PLACED} msg]} {error "setPlacementStatus failed: $msg"}
puts "MOVE_WORST_BUFFER new_bbox=[[$inst getBBox] xMin],[[$inst getBBox] yMin]"
write_db $::env(RESULTS_DIR)/5_read_control_worst_buffer_moved.odb
write_sdc $::env(RESULTS_DIR)/5_read_control_worst_buffer_moved.sdc
puts "MOVE_WORST_BUFFER complete"
