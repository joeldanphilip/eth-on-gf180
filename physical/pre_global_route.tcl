# GF180 liberty/OpenDB marks the synthesis constant-driver nets one_ and zero_
# as POWER/GROUND even though they are signal tie nets with no VDD/VSS
# connectivity. TritonRoute rejects non-special POWER/GROUND nets. Reclassify
# only these named constant nets; VDD and VSS remain true special nets handled
# by PDN.
set block [ord::get_db_block]
foreach constant_net {one_ zero_} {
  set net [$block findNet $constant_net]
  if {$net != "NULL"} {
    $net setSigType SIGNAL
    puts "PHYSICAL_ROUTE_FIX $constant_net sigtype=[$net getSigType]"
  }
}
