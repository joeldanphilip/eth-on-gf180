# Repair estimates calibrated against the selected 5LM OpenRCX tables.
# Resistance is table ohm/nm * 1000. C is a conservative optimization
# estimate; acceptance still uses separately extracted WC/BC/TC SPEFs.
set rc_r [dict create \
  WC {0.628392 0.516178 0.516178 0.516178 0.161545} \
  BC {0.274687 0.225636 0.225636 0.225636 0.0585537} \
  TC {0.395696 0.325036 0.325036 0.325036 0.0932048}]
set rc_c [dict create \
  WC {0.00035 0.00035 0.00038 0.00040 0.00041} \
  BC {0.00022 0.00022 0.00024 0.00025 0.00026} \
  TC {0.00027 0.00027 0.00029 0.00030 0.00031}]
set rc_via [dict create WC 16.845 BC 4.23 TC 4.5]
set active $::env(CORNER)
if {![dict exists $rc_r $active]} {error "Unknown GF180 corner $active"}
# Unqualified setters also update the database properties used by extraction.
for {set i 1} {$i <= 5} {incr i} {
  set_layer_rc -layer Metal$i \
    -resistance [lindex [dict get $rc_r $active] [expr {$i-1}]] \
    -capacitance [lindex [dict get $rc_c $active] [expr {$i-1}]]
}
foreach via {Via1 Via2 Via3 Via4} {
  set_layer_rc -via $via -resistance [dict get $rc_via $active]
}
# Explicit corner setters preserve the DB properties while configuring each
# STA scene independently (confirmed in the installed setter implementation).
foreach corner {WC BC TC} {
  for {set i 1} {$i <= 5} {incr i} {
    set_layer_rc -corner $corner -layer Metal$i \
      -resistance [lindex [dict get $rc_r $corner] [expr {$i-1}]] \
      -capacitance [lindex [dict get $rc_c $corner] [expr {$i-1}]]
  }
  foreach via {Via1 Via2 Via3 Via4} {
    set_layer_rc -corner $corner -via $via -resistance [dict get $rc_via $corner]
  }
  set_wire_rc -corner $corner -signal -layer Metal2
  set_wire_rc -corner $corner -clock -layer Metal4
}
puts "EXTRACTED_RC_REPAIR_MODEL active=$active resistance_from_OpenRCX=true capacitance=conservative_estimate"
