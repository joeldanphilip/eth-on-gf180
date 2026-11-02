include $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/pipeline_design.mk
export DESIGN_NICKNAME := ethernet_pipeline_25u_4096
export CORE_UTILIZATION := 25
export PLACE_DENSITY := 0.35
