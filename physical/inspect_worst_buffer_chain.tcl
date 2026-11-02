# Read-only physical audit for the current extracted WC worst path.
source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_read_control_final.odb 6_read_control_final.sdc
set block [ord::get_db_block]
foreach name {place22443 place22442 place22445 place24939 place24894 place21605 place21598 place25436 place22649 place22648 place22646 place21715 place21714 place21708 _215198_ _215200_ _215206_ _191822_ _191823_ _191824_ _166781_ _166784_ _166786_ _166615_ _166618_ _166621_ _193947_ _193949_ _193952_ _193928_ _193932_ _193935_ _193959_ _193962_ _193963_ _186299_ _186301_ _186307_ _398057_ _398037_ _380134_ _380135_ _380132_ _424600_ _424563_ _424567_ _424547_ _424630_ _409754_ _424597_ _348115_ _400231_} {
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
