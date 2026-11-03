include $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/pipeline_design.mk

export DESIGN_NICKNAME := ethernet_pipeline_deep_4096
export SYNTH_NETLIST_FILES := $(PROJECT_DIR)/build/gf180_physical_pipeline_deep/mac_hold.v
export VERILOG_FILES := $(SYNTH_NETLIST_FILES)
export DETAILED_ROUTE_ARGS := -droute_end_iter 64 -drc_report_iter_step 5
