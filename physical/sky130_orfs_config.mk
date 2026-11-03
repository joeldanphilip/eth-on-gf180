PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
SKY_MACRO_DIR := $(PROJECT_DIR)/build/sky130_sram_macros/sky130_sram_2kbyte_1rw1r_32x512_8

export DESIGN_NAME = eth_mac_1g_fifo
export DESIGN_NICKNAME = ethernet_sky130_4096
export PLATFORM = sky130hd

# The mapped netlist is used as the physical implementation input.  The
# wrapper source supplies the SRAM black-box declaration for elaboration.
export VERILOG_FILES = $(PROJECT_DIR)/build/sky130/mac_mapped.v \
                       $(PROJECT_DIR)/rtl/sky130_sram_2kbyte_1rw1r_32x512_8_blackbox.v
export SDC_FILE = $(PROJECT_DIR)/sta/sky130.sdc

export ADDITIONAL_LEFS = $(SKY_MACRO_DIR)/sky130_sram_2kbyte_1rw1r_32x512_8.lef
export ADDITIONAL_GDS = $(SKY_MACRO_DIR)/sky130_sram_2kbyte_1rw1r_32x512_8.gds
export ADDITIONAL_LIBS =

export CORE_AREA = 100 100 3900 2400
export DIE_AREA = 0 0 4000 2500
export MACRO_PLACEMENT_TCL = $(PROJECT_DIR)/physical/sky130_macro_place.tcl
export POST_FLOORPLAN_TCL = $(PROJECT_DIR)/physical/sky130_floorplan_io.tcl
export POST_MACRO_PLACE_TCL = $(PROJECT_DIR)/physical/sky130_macro_legalize.tcl
export POST_TAPCELL_TCL = $(PROJECT_DIR)/physical/sky130_tapcell_legalize.tcl
export PDN_TCL = $(PROJECT_DIR)/physical/sky130_pdn.tcl
export RTLMP_ARGS = -max_num_macro 8 -min_num_macro 8 -max_num_level 1 \
                    -area_weight 0.1 -outline_weight 100.0 \
                    -wirelength_weight 100.0 -boundary_weight 50.0 \
                    -notch_weight 50.0 -target_util 0.45 \
                    -report_directory $(PROJECT_DIR)/build/sky130/rtlmp
export CORE_UTILIZATION =
export PLACE_DENSITY = 0.45
export TNS_END_PERCENT = 100
export SETUP_SLACK_MARGIN = 0.0
export HOLD_SLACK_MARGIN = 0.0
export OPENROAD_EXE = $(PROJECT_DIR)/physical/bin/openroad
export OPENSTA_EXE = $(PROJECT_DIR)/physical/bin/sta
