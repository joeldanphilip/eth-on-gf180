set root /home/joelphilip/Documents/ethernet_formal
set platform $root/tools/ORFS_physical/flow/platforms/gf180
read_lef $platform/lef/gf180mcu_5LM_1TM_9K_9t_tech.lef
read_lef $platform/lef/gf180mcu_5LM_1TM_9K_9t_sc.lef
read_liberty $platform/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib.gz
read_verilog $root/physical/tests/cdl_smoke.v
link_design cdl_smoke
add_global_connection -net VDD -pin_pattern {^VDD$} -power
add_global_connection -net VSS -pin_pattern {^VSS$} -ground
global_connect
file mkdir $root/build/native_verify
write_cdl -masters [list $root/tools/gf180_9t_lvs/cells/nand2/gf180mcu_fd_sc_mcu9t5v0__nand2_4.cdl] $root/build/native_verify/cdl_smoke.cdl
