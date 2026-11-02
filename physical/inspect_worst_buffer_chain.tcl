# Read-only physical audit for the current extracted WC worst path.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_read_control_final.odb 6_read_control_final.sdc
set block [ord::get_db_block]
foreach name {place22443 place22442 place22445 _166781_ _166784_ _166786_ _166615_ _166618_ _166621_ _398057_ _398037_ _424600_} {
  set inst [$block findInst $name]
  if {$inst eq "NULL"} {
    puts "WORST_CHAIN missing=$name"
    continue
  }
  set box [$inst getBBox]
  puts "WORST_CHAIN inst=$name master=[[$inst getMaster] getName] orient=[$inst getOrient] x=[$box xMin] y=[$box yMin] x2=[$box xMax] y2=[$box yMax]"
  foreach term [$inst getITerms] {
    set net [$term getNet]
    if {$net ne "NULL"} {
      puts "  pin=[[$term getMTerm] getName] net=[$net getName] fanout=[llength [$net getITerms]]"
    }
  }
}
