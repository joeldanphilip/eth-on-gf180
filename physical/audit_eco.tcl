# Diagnostic ECO on a copy of the CTS checkpoint; keep the original immutable.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_cts.odb 4_cts.sdc
set_propagated_clock [all_clocks]
set block [ord::get_db_block]
set count 0
foreach inst [$block getInsts] {
  if {[string match output* [$inst getName]] && [string match *__dlyb_* [[$inst getMaster] getName]]} {
    replace_cell [$inst getName] gf180mcu_fd_sc_mcu9t5v0__buf_16
    incr count
  }
}
puts "OUTPUT_BUFFER_ECO replaced=$count"
estimate_parasitics -placement
set report $::env(REPORTS_DIR)/audit_output_buffer_eco.rpt
foreach corner {WC BC TC} {
  puts "AUDIT_CORNER $corner"
  report_checks -scenes [list $corner] -path_delay min_max -group_path_count 3 -format full_clock_expanded > ${report}.${corner}
  report_checks -scenes [list $corner] -from [all_registers -clock_pins] -to [all_registers -data_pins] -path_delay min_max -group_path_count 3 -format full_clock_expanded > ${report}.${corner}.internal
}
write_db $::env(RESULTS_DIR)/4_output_buffer_eco.odb
