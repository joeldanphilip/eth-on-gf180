source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_final.odb 6_final.sdc
global_connect
write_cdl -include_fillers -masters [list /home/joelphilip/Documents/ethernet_formal/build/gf180_lvs/masters.cdl] $::env(RESULTS_DIR)/6_final_raw.cdl
