include $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/pipeline_eco_design.mk
export LAYER_PARASITICS_FILE := $(PROJECT_DIR)/physical/layer_rc_extracted.tcl
