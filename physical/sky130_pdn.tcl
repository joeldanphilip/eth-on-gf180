# Sky130HD standard-cell grid plus explicit connections for the OpenRAM
# vccd1/vssd1 pins.  The stock platform file handles VPWR/VGND cells.
source $::env(PLATFORM_DIR)/pdn.tcl
add_global_connection -net {VDD} -inst_pattern {.*} -pin_pattern {^vccd1$} -power
add_global_connection -net {VSS} -inst_pattern {.*} -pin_pattern {^vssd1$} -ground
global_connect -force

# The mapped black-box netlist gives each macro instance a distinct power wire.
# Its LEF marks these pins as power/ground, but this OpenROAD build treats the
# black-box ITerms as SIGNAL during global_connect.  Reconnect the eight hard
# macro terminals explicitly so pdngen sees them on the CORE supply nets.
set block [ord::get_db_block]
set vdd [$block findNet VDD]
if {$vdd eq "" || $vdd eq "NULL"} {
    set vdd [odb::dbNet_create $block VDD]
}
$vdd setSigType POWER
set vss [$block findNet VSS]
if {$vss eq "" || $vss eq "NULL"} {
    set vss [odb::dbNet_create $block VSS]
}
$vss setSigType GROUND
foreach inst [$block getInsts] {
    if {[[$inst getMaster] getName] ne "sky130_sram_2kbyte_1rw1r_32x512_8"} {
        continue
    }
    foreach iterm [$inst getITerms] {
        set mterm [$iterm getMTerm]
        set mname [$mterm getName]
        if {$mname eq "vccd1"} {
            $iterm disconnect
            $iterm connect $vdd
        } elseif {$mname eq "vssd1"} {
            $iterm disconnect
            $iterm connect $vss
        }
    }
}
