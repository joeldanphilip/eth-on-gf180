# Lightweight timing checks avoid repeating expensive vectorless power reports.
set qor_file $::env(REPORTS_DIR)/physical_${physical_qor_stage}_timing.rpt
set fd [open $qor_file w]
puts $fd "Stage: $physical_qor_stage; WC/BC/TC cell corners; 8 ns clocks"
if {[string match extracted* $physical_qor_stage]} {
  puts $fd "Interconnect uses the loaded corner-specific OpenRCX SPEFs; see per-corner reports."
} else {
  puts $fd "Interconnect is placement/global-route estimation until final OpenRCX extraction."
}
close $fd
check_setup -verbose >> $qor_file
report_worst_slack -max -digits 4 >> $qor_file
report_worst_slack -min -digits 4 >> $qor_file
report_tns >> $qor_file
report_checks -path_delay max -group_path_count 2 -format full_clock_expanded -fields {slew cap fanout} >> $qor_file
report_checks -path_delay min -group_path_count 2 -format full_clock_expanded -fields {slew cap fanout} >> $qor_file
report_check_types -max_slew -max_capacitance -violators >> $qor_file
puts "PHYSICAL_QOR $physical_qor_stage: $qor_file"
report_worst_slack -max -digits 4
report_worst_slack -min -digits 4
