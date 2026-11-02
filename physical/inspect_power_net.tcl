read_db $::env(ODB)
set block [ord::get_db_block]
foreach net [$block getNets] {
  if {[$net getName] eq "one_" || [$net getSigType] eq "POWER" || [$net getSigType] eq "GROUND"} {
    puts "NET [$net getName] type=[$net getSigType] iterms=[llength [$net getITerms]] bterms=[llength [$net getBTerms]]"
    if {[$net getName] in {one_ zero_}} {
      foreach term [$net getITerms] {
        puts "  PIN [[$term getInst] getName]/[[$term getMTerm] getName] type=[[$term getMTerm] getIoType]"
      }
      foreach term [$net getBTerms] {
        puts "  PORT [$term getName] type=[$term getIoType]"
      }
    }
  }
}
