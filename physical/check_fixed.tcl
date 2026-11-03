read_liberty tools/ORFS/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db build/sky130/fixed_final.odb
read_sdc tools/ORFS/flow/results/sky130hd/ethernet_sky130_4096/base/6_final.sdc
source tools/ORFS/flow/platforms/sky130hd/setRC.tcl
estimate_parasitics -global_routing
check_placement -verbose
report_check_types -max_slew -max_cap -violators
report_checks -path_delay max -group_path_count 1 -format summary
report_checks -path_delay min -group_path_count 1 -format summary
write_def build/sky130/fixed_final.def
exit
