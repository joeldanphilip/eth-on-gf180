PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
export DESIGN_NICKNAME := ethernet_decoupled_4096
export SYNTH_NETLIST_FILES := $(PROJECT_DIR)/build/gf180_decoupled_read/mac_mapped.v
include $(PROJECT_DIR)/physical/design.mk
# Respect GF180 pin-access restrictions and avoid automatic port delay cells.
override export DONT_USE_CELLS := *_1 *__dly*
export SKIP_CTS_REPAIR_TIMING := 1
export POST_CTS_TCL := $(PROJECT_DIR)/physical/qor_soc_cts.tcl
export CTS_BUF_LIST := gf180mcu_fd_sc_mcu9t5v0__clkbuf_8 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16 gf180mcu_fd_sc_mcu9t5v0__clkbuf_20
export CTS_CLUSTER_SIZE := 64
export CTS_CLUSTER_DIAMETER := 200
export REMOVE_ABC_BUFFERS := 1
export PRE_GLOBAL_ROUTE_TCL := $(PROJECT_DIR)/physical/decoupled_pre_grt.tcl
# The direct checkpoint-replay targets do not inherit every platform variable
# from the normal flow environment. Keep the GF180 tie-cell contract explicit
# for constant-net repair and audit hooks.
export TIEHI_CELL_AND_PORT := gf180mcu_fd_sc_mcu9t5v0__tieh Z
export TIELO_CELL_AND_PORT := gf180mcu_fd_sc_mcu9t5v0__tiel ZN
