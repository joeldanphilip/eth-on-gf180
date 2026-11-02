# Read-only audit of the currently failing extracted path's physical cells.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_read_control_final.odb 6_read_control_final.sdc
set block [ord::get_db_block]
foreach name {place22443 place22441 _165846_ _165847_ _165850_} {
  set inst [$block findInst $name]
  if {$inst eq "NULL"} {
    puts "READ_CONTROL_WORST_PATH missing=$name"
    continue
  }
  puts "READ_CONTROL_WORST_PATH inst=$name master=[[$inst getMaster] getName] x=[[$inst getBBox] xMin] y=[[$inst getBBox] yMin]"
  foreach term [$inst getITerms] {
    set net [$term getNet]
    if {$net ne "NULL"} {
      puts "  pin=[[$term getMTerm] getName] net=[$net getName] fanout=[llength [$net getITerms]]"
    }
  }
}
