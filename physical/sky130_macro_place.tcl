# Deterministic placement for the eight 2 kB SRAM macros.
set macros {}
set block [ord::get_db_block]
foreach inst [$block getInsts] {
    if {[[$inst getMaster] getName] eq "sky130_sram_2kbyte_1rw1r_32x512_8"} {
        lappend macros [$inst getName]
    }
}
if {[llength $macros] != 8} {
    error "expected 8 Sky130 SRAM instances, found [llength $macros]"
}

set x0 220
set y0 258.4
set dx 760
set dy 620.32
set index 0
foreach macro $macros {
    set col [expr {$index % 4}]
    set row [expr {$index / 4}]
    set x [expr {$x0 + $col * $dx}]
    set y [expr {$y0 + $row * $dy}]
    place_macro -macro_name $macro \
        -location [list $x $y] -orientation R0 -exact
    incr index
}
