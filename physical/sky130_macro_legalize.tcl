# The ORFS compatibility flow validates all placement objects before PDN.
# Run an initial global placement after the fixed SRAM coordinates are known,
# then legalize the tie cells inserted during floorplan repair.
set macro_names {}
set block [ord::get_db_block]
foreach inst [$block getInsts] {
    if {[[$inst getMaster] getName] eq "sky130_sram_2kbyte_1rw1r_32x512_8"} {
        lappend macro_names [$inst getName]
    }
}
set_placement_padding -instances $macro_names -left 0 -right 0
set_placement_padding -masters sky130_sram_2kbyte_1rw1r_32x512_8 -left 0 -right 0
global_placement -timing_driven -routability_driven -density 0.45
set_placement_padding -global -left 0 -right 0
detailed_placement
check_placement -verbose
