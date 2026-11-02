# GF180 6LM/7-track experiment.  This is a real platform variant: the
# repository contains matching 7t LEF/GDS/Liberty/technology views and 1p6m
# RCX rules.  It is not an SRAM substitute; it only adds one routing layer
# and uses the corresponding 7-track standard-cell library.
include $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/decoupled_design.mk

export DESIGN_NICKNAME := ethernet_pipeline_6m7t_4096
export TRACK_OPTION := 7t
export METAL_OPTION := 6LM_1TM
export KVALUE := 9
export POWER_OPTION := 5v0
export SYNTH_NETLIST_FILES := $(PROJECT_DIR)/build/gf180_6m7t/mac_mapped.v
export LAYER_PARASITICS_FILE := $(PROJECT_DIR)/physical/layer_rc_6m7t.tcl

override export DONT_USE_CELLS := *_1 *__dly*
export CTS_BUF_LIST := gf180mcu_fd_sc_mcu7t5v0__clkbuf_8 gf180mcu_fd_sc_mcu7t5v0__clkbuf_16 gf180mcu_fd_sc_mcu7t5v0__clkbuf_20
export TIEHI_CELL_AND_PORT := gf180mcu_fd_sc_mcu7t5v0__tieh Z
export TIELO_CELL_AND_PORT := gf180mcu_fd_sc_mcu7t5v0__tiel ZN
export ABC_DRIVER_CELL := gf180mcu_fd_sc_mcu7t5v0__buf_4
export MIN_BUF_CELL_AND_PORTS := gf180mcu_fd_sc_mcu7t5v0__dlya_4 I Z

export MIN_ROUTING_LAYER := Metal2
export MAX_ROUTING_LAYER := MetalTop
export DISABLE_VIA_GEN := 0
export DETAILED_ROUTE_ARGS := -droute_end_iter 64 -drc_report_iter_step 5
export PRE_GLOBAL_ROUTE_TCL := $(PROJECT_DIR)/physical/decoupled_pre_grt_6m7t.tcl

export BC_RCX_RULES := $(PLATFORM_DIR)/openROAD/rcx/gf180mcu_1p6m_1tm_9k_sp_smim_OPTB_bst.rules
export WC_RCX_RULES := $(PLATFORM_DIR)/openROAD/rcx/gf180mcu_1p6m_1tm_9k_sp_smim_OPTB_wst.rules
export TC_RCX_RULES := $(PLATFORM_DIR)/openROAD/rcx/gf180mcu_1p6m_1tm_9k_sp_smim_OPTB_typ.rules
export BC_RCX_RC_CORNER := FuncRCmin
export WC_RCX_RC_CORNER := FuncRCmax
export TC_RCX_RC_CORNER := FuncRCtyp
