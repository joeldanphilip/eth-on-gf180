source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_cts.odb 4_cts.sdc
source /home/joelphilip/Documents/ethernet_formal/physical/decoupled_pre_grt.tcl
set block [ord::get_db_block]
foreach name {one_ zero_} {
  set net [$block findNet $name]
  if {$net == "NULL"} {continue}
  set drivers 0
  foreach term [$net getITerms] {
    if {[[$term getMTerm] getIoType] == "OUTPUT"} {incr drivers}
  }
  puts "CONSTANT_AUDIT $name drivers=$drivers type=[$net getSigType]"
  if {$drivers != 1} {error "Invalid physical constant driver count on $name"}
}
write_db $::env(RESULTS_DIR)/4_constants_audited.odb
