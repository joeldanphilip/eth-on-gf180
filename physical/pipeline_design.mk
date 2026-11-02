include $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/decoupled_design.mk
export DESIGN_NICKNAME := ethernet_pipeline_4096
export SYNTH_NETLIST_FILES := $(PROJECT_DIR)/build/gf180_physical_pipeline/mac_mapped.v
# The first detailed-route pass showed Via2/cut-spacing and Metal2 shorts.
# Override the GF180 platform default for this targeted routing experiment.
export DISABLE_VIA_GEN := 0
export DETAILED_ROUTE_ARGS := -droute_end_iter 64 -drc_report_iter_step 5
