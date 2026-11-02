# Route the localized, SAT-proven ECO using the existing 9t/5LM process.
include $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/pipeline_design.mk
export NUM_CORES := 8
# Final acceptance must analyze exactly the finished database used for GDS.
export SIGNOFF_STAGE := 6_final
export PRE_GLOBAL_ROUTE_TCL := $(PROJECT_DIR)/physical/eco_pre_grt.tcl
export POST_GLOBAL_ROUTE_TCL := $(PROJECT_DIR)/physical/eco_post_grt.tcl
export SETUP_SLACK_MARGIN := 0.10
export HOLD_SLACK_MARGIN := 0.03
# Let repair iterations run; save sparse DRC snapshots to control disk usage.
export DETAILED_ROUTE_ARGS := -droute_end_iter 64 -drc_report_iter_step 64
