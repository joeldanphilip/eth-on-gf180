PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
# The installed OpenROAD binary is 26Q2 (2026-05).  Keep the newer checkout
# intact for reference, but run the physical flow from the last ORFS revision
# released before that binary so Tcl command APIs stay aligned.
FLOW_DIR := $(PROJECT_DIR)/tools/ORFS_physical/flow
export OPENROAD_EXE ?= $(PROJECT_DIR)/physical/bin/openroad
export OPENSTA_EXE ?= $(PROJECT_DIR)/physical/bin/sta
export YOSYS_EXE ?= $(PROJECT_DIR)/scripts/yosys
export PYTHON_EXE ?= $(PROJECT_DIR)/.venv/bin/python
export KLAYOUT_CMD ?= $(PROJECT_DIR)/physical/bin/klayout
export WORK_HOME ?= $(PROJECT_DIR)/build/physical
export PATH := $(PROJECT_DIR)/physical/bin:$(PROJECT_DIR)/scripts:$(PATH)
.PHONY: all preflight floorplan place cts route finish gds
all: gds
preflight:
	$(PYTHON_EXE) $(PROJECT_DIR)/physical/preflight.py
floorplan place cts route finish gds:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/design.mk $@

# Explicit diagnostic stages operate on saved checkpoints and do not replay
# upstream synthesis/placement. Override WORK_HOME to select the evidence run.
.PHONY: audit-eco repair-io-hold
audit-eco:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/design.mk --eval='physical_audit:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/audit_eco.tcl' physical_audit
repair-io-hold:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/design.mk --eval='physical_hold:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_io_hold.tcl' physical_hold

.PHONY: repair-setup
repair-setup:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/design.mk --eval='physical_setup:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_setup.tcl' physical_setup

.PHONY: clock-latency-trial
clock-latency-trial:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/design.mk --eval='physical_clock:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/clock_latency_trial.tcl' physical_clock

.PHONY: repair-balanced
repair-balanced:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/design.mk --eval='physical_balanced:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_balanced.tcl' physical_balanced

.PHONY: repair-port-hold
repair-port-hold:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/design.mk --eval='physical_port_hold:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_port_hold.tcl' physical_port_hold

.PHONY: interface-skew-trial
interface-skew-trial:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/design.mk --eval='physical_skew:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/interface_skew_trial.tcl' physical_skew

.PHONY: repair-core check-core-candidate
repair-core:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/design.mk --eval='physical_core:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_core.tcl' physical_core
check-core-candidate:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/design.mk --eval='physical_core_check:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/check_core_candidate.tcl' physical_core_check

.PHONY: check-soc-candidate
check-soc-candidate:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/design.mk --eval='physical_soc_check:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/check_soc_candidate.tcl' physical_soc_check

.PHONY: decoupled-cts
decoupled-cts:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/decoupled_design.mk cts

.PHONY: decoupled-repair
decoupled-repair:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/decoupled_design.mk --eval='physical_decoupled_repair:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_decoupled.tcl' physical_decoupled_repair

.PHONY: decoupled-audit-constants
decoupled-audit-constants:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/decoupled_design.mk --eval='physical_constants:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/audit_constants.tcl' physical_constants

.PHONY: decoupled-extract decoupled-check-extracted
decoupled-extract:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/decoupled_design.mk --eval='physical_extract:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/extract_corner.tcl' physical_extract
decoupled-check-extracted:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/decoupled_design.mk --eval='physical_extracted_check:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/check_extracted.tcl' physical_extracted_check

.PHONY: pipeline-cts pipeline-repair pipeline-grt pipeline-drt pipeline-route pipeline-extract pipeline-check-extracted pipeline-gds
pipeline-cts:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_design.mk cts
pipeline-repair:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_design.mk --eval='physical_pipeline_repair:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_decoupled.tcl' physical_pipeline_repair
pipeline-route:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_design.mk do-route
pipeline-grt:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_design.mk do-grt
pipeline-drt:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_design.mk do-5_2_route do-5_3_fillcell do-5_route do-5_route.sdc
pipeline-extract:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_design.mk --eval='physical_pipeline_extract:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/extract_corner.tcl' physical_pipeline_extract
pipeline-check-extracted:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_design.mk --eval='physical_pipeline_extracted_check:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/check_extracted.tcl' physical_pipeline_extracted_check
pipeline-gds:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_design.mk gds
.PHONY: pipeline-m1-grt pipeline-m1-drt
.PHONY: empty-eco-export empty-eco-apply
carry-eco-apply:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_m1_design.mk --eval='carry_apply:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/apply_carry_eco.tcl' carry_apply
empty-eco-repair:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_m1_design.mk --eval='empty_repair:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_empty_eco.tcl' empty_repair
empty-eco-finalize:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_m1_design.mk --eval='empty_finalize:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/finalize_empty_eco.tcl' empty_finalize
tx-reduction-export:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_m1_design.mk --eval='tx_export:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/export_tx_reduction.tcl' tx_export
tx-reduction-apply:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_m1_design.mk --eval='tx_apply:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/apply_tx_reduction.tcl' tx_apply
tx-and-reduction-apply:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_m1_design.mk --eval='tx_and_apply:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/apply_tx_and_reduction.tcl' tx_and_apply
.PHONY: eco-grt eco-drt
eco-grt:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk do-grt
eco-drt:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk do-5_2_route do-5_3_fillcell do-5_route do-5_route.sdc
	$(PYTHON_EXE) $(PROJECT_DIR)/scripts/check_routed_checkpoint.py --work-home $(WORK_HOME)
.PHONY: eco-check-route
eco-check-route:
	$(PYTHON_EXE) $(PROJECT_DIR)/scripts/check_routed_checkpoint.py --work-home $(WORK_HOME)
.PHONY: eco-bind-power
eco-bind-power:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_bind_power:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/finalize_route_power.tcl' eco_bind_power
.PHONY: eco-repair-extracted-controls
eco-repair-extracted-controls:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_buffer_design.mk --eval='eco_controls:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_extracted_controls.tcl' eco_controls
eco-clean-guides:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_guides:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/clean_eco_guides.tcl' eco_guides
eco-inspect-grid:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_grid:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/inspect_eco_grid.tcl' eco_grid
.PHONY: eco-inspect-cdc
eco-inspect-cdc:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_cdc_inspect:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/inspect_cdc_paths.tcl' eco_cdc_inspect
.PHONY: eco-inspect-read-controls
eco-inspect-read-controls:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_controls:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/inspect_read_controls.tcl' eco_read_controls
.PHONY: eco-repair-read-controls
eco-repair-read-controls:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_buffer_design.mk --eval='eco_read_controls_repair:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_read_controls.tcl' eco_read_controls_repair
.PHONY: eco-resize-read-controls
eco-resize-read-controls:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_controls_resize:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/resize_read_controls.tcl' eco_read_controls_resize
.PHONY: eco-route-sized-read-controls
eco-route-sized-read-controls:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_controls_route:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/detail_route_read_control_size.tcl' eco_read_controls_route
.PHONY: eco-repair-saved-antennas
eco-repair-saved-antennas:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_saved_antennas:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_saved_antennas.tcl' eco_saved_antennas
.PHONY: eco-repair-saved-antennas-round2
eco-repair-saved-antennas-round2:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_saved_antennas_round2:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_saved_antennas_round2.tcl' eco_saved_antennas_round2
.PHONY: eco-repair-saved-antennas-round3
eco-repair-saved-antennas-round3:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_saved_antennas_round3:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_saved_antennas_round3.tcl' eco_saved_antennas_round3
.PHONY: eco-repair-saved-antennas-round4
eco-repair-saved-antennas-round4:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_saved_antennas_round4:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_saved_antennas_round4.tcl' eco_saved_antennas_round4
.PHONY: eco-finish-read-control-candidate
eco-finish-read-control-candidate:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_control_finish:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/finalize_read_control_candidate.tcl' eco_read_control_finish
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_control_report:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/report_read_control_candidate.tcl' eco_read_control_report
.PHONY: eco-extract-read-control-candidate
eco-extract-read-control-candidate:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_control_extract:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/extract_read_control_candidate.tcl' eco_read_control_extract
.PHONY: eco-check-read-control-candidate
eco-check-read-control-candidate:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_control_check:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/check_read_control_extracted.tcl' eco_read_control_check
.PHONY: eco-inspect-read-control-worst-path
eco-inspect-read-control-worst-path:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_control_worst_path:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/inspect_read_control_worst_path.tcl' eco_read_control_worst_path
.PHONY: eco-inspect-worst-buffer-chain
eco-inspect-worst-buffer-chain:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_inspect_worst_buffer_chain:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/inspect_worst_buffer_chain.tcl' eco_inspect_worst_buffer_chain
.PHONY: eco-help-place-cell
eco-help-place-cell:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_help_place_cell:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/help_place_cell.tcl' eco_help_place_cell
.PHONY: eco-move-worst-buffer-near-aoi
eco-move-worst-buffer-near-aoi:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_move_worst_buffer_near_aoi:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/move_worst_buffer_near_aoi.tcl' eco_move_worst_buffer_near_aoi
.PHONY: eco-route-worst-buffer-moved
eco-route-worst-buffer-moved:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_route_worst_buffer_moved:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/detail_route_worst_buffer_moved.tcl' eco_route_worst_buffer_moved
.PHONY: eco-move-second-worst-buffer
eco-move-second-worst-buffer:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_move_second_worst:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/move_second_worst_buffer_near_aoi.tcl' eco_move_second_worst
.PHONY: eco-route-second-worst-buffer
eco-route-second-worst-buffer:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_route_second_worst:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/detail_route_worst_buffer_moved2.tcl' eco_route_second_worst
.PHONY: eco-resize-read-controls-round2
eco-resize-read-controls-round2:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_controls_resize_round2:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/resize_read_controls_round2.tcl' eco_read_controls_resize_round2
.PHONY: eco-route-sized-read-controls-round2
eco-route-sized-read-controls-round2:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_controls_route_round2:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/detail_route_read_control_round2.tcl' eco_read_controls_route_round2
.PHONY: eco-repair-read-control-round2-antennas
eco-repair-read-control-round2-antennas:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_control_round2_antennas:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_read_control_round2_antennas.tcl' eco_read_control_round2_antennas
.PHONY: eco-repair-read-control-round2-antennas-next
eco-repair-read-control-round2-antennas-next:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_control_round2_antennas_next:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_read_control_round2_antennas_next.tcl' eco_read_control_round2_antennas_next
.PHONY: eco-repair-read-control-round2-antennas-final
eco-repair-read-control-round2-antennas-final:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_control_round2_antennas_final:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_read_control_round2_antennas_final.tcl' eco_read_control_round2_antennas_final
.PHONY: eco-repair-read-control-round2-antennas-last
eco-repair-read-control-round2-antennas-last:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_control_round2_antennas_last:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_read_control_round2_antennas_last.tcl' eco_read_control_round2_antennas_last
.PHONY: eco-repair-read-control-antenna-jumper
eco-repair-read-control-antenna-jumper:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_control_antenna_jumper:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_read_control_antenna_jumper.tcl' eco_read_control_antenna_jumper
.PHONY: eco-resize-read-controls-round3
eco-resize-read-controls-round3:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_controls_resize_round3:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/resize_read_controls_round3.tcl' eco_read_controls_resize_round3
.PHONY: eco-route-sized-read-controls-round3
eco-route-sized-read-controls-round3:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_controls_route_round3:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/detail_route_read_control_round3.tcl' eco_read_controls_route_round3
.PHONY: eco-route-sized-read-controls-round3-incremental
eco-route-sized-read-controls-round3-incremental:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_controls_route_round3_incremental:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/detail_route_read_control_round3_incremental.tcl' eco_read_controls_route_round3_incremental
.PHONY: eco-route-sized-read-controls-round3-local
eco-route-sized-read-controls-round3-local:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_controls_route_round3_local:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/detail_route_read_control_round3_local.tcl' eco_read_controls_route_round3_local
.PHONY: eco-resize-worst-buffer-local
eco-resize-worst-buffer-local:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_resize_worst_buffer:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/resize_worst_buffer_local.tcl' eco_resize_worst_buffer
.PHONY: eco-route-worst-buffer-local
eco-route-worst-buffer-local:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_route_worst_buffer:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/detail_route_worst_buffer_local.tcl' eco_route_worst_buffer
.PHONY: eco-resize-worst-buffer-fixedsite
eco-resize-worst-buffer-fixedsite:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_resize_worst_buffer_fixedsite:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/resize_worst_buffer_fixedsite.tcl' eco_resize_worst_buffer_fixedsite
.PHONY: eco-route-worst-buffer-fixedsite
eco-route-worst-buffer-fixedsite:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_route_worst_buffer_fixedsite:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/detail_route_worst_buffer_fixedsite.tcl' eco_route_worst_buffer_fixedsite
.PHONY: eco-resize-worst-buffer-nofill
eco-resize-worst-buffer-nofill:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_resize_worst_buffer_nofill:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/resize_worst_buffer_nofill.tcl' eco_resize_worst_buffer_nofill
.PHONY: eco-route-worst-buffer-nofill
eco-route-worst-buffer-nofill:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_route_worst_buffer_nofill:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/detail_route_worst_buffer_nofill.tcl' eco_route_worst_buffer_nofill
.PHONY: eco-legalize-worst-buffer-nofill
eco-legalize-worst-buffer-nofill:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_legalize_worst_buffer_nofill:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/legalize_worst_buffer_nofill.tcl' eco_legalize_worst_buffer_nofill
.PHONY: eco-route-worst-buffer-legal
eco-route-worst-buffer-legal:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_route_worst_buffer_legal:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/detail_route_worst_buffer_legal.tcl' eco_route_worst_buffer_legal
.PHONY: eco-reroute-sized-read-controls
eco-reroute-sized-read-controls:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_read_controls_reroute:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/reroute_read_control_size.tcl' eco_read_controls_reroute
.PHONY: eco-extract eco-check-extracted eco-finish eco-gds eco-cdl
eco-extract:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_extract:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/extract_corner.tcl' eco_extract
eco-check-extracted:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_check:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/check_extracted.tcl' eco_check
.PHONY: eco-check-cdc
eco-check-cdc:
	$(PYTHON_EXE) $(PROJECT_DIR)/scripts/build_cdc_endpoints.py
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_cdc_check:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/check_cdc_extracted.tcl' eco_cdc_check
eco-finish:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk do-finish
eco-gds:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk do-gds
eco-cdl:
	$(PYTHON_EXE) $(PROJECT_DIR)/scripts/prepare_gf180_lvs.py
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_eco_design.mk --eval='eco_cdl:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/export_final_cdl.tcl' eco_cdl
	$(PYTHON_EXE) $(PROJECT_DIR)/scripts/prepare_gf180_lvs.py --input $(WORK_HOME)/results/gf180/ethernet_pipeline_4096/base/6_final_raw.cdl --output $(WORK_HOME)/results/gf180/ethernet_pipeline_4096/base/6_final_lvs.cdl
.PHONY: eco-drc eco-lvs
eco-drc:
	$(PYTHON_EXE) $(PROJECT_DIR)/physical/run_gds_verification.py drc --work-home $(WORK_HOME)
eco-lvs:
	$(PYTHON_EXE) $(PROJECT_DIR)/physical/run_gds_verification.py lvs --work-home $(WORK_HOME)
.PHONY: eco-verify-final
eco-verify-final:
	$(MAKE) -f $(PROJECT_DIR)/physical/Makefile eco-check-route
	$(MAKE) -f $(PROJECT_DIR)/physical/Makefile eco-bind-power
	$(MAKE) -f $(PROJECT_DIR)/physical/Makefile CORNER=WC eco-finish
	$(MAKE) -f $(PROJECT_DIR)/physical/Makefile CORNER=WC eco-extract
	$(MAKE) -f $(PROJECT_DIR)/physical/Makefile CORNER=BC eco-extract
	$(MAKE) -f $(PROJECT_DIR)/physical/Makefile CORNER=TC eco-extract
	$(MAKE) -f $(PROJECT_DIR)/physical/Makefile eco-check-extracted
	$(MAKE) -f $(PROJECT_DIR)/physical/Makefile eco-check-cdc
	$(MAKE) -f $(PROJECT_DIR)/physical/Makefile eco-gds
	$(MAKE) -f $(PROJECT_DIR)/physical/Makefile eco-cdl
	$(MAKE) -f $(PROJECT_DIR)/physical/Makefile eco-drc
	$(MAKE) -f $(PROJECT_DIR)/physical/Makefile eco-lvs
empty-eco-export:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_m1_design.mk --eval='empty_export:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/export_empty_cone.tcl' empty_export
empty-eco-apply:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_m1_design.mk --eval='empty_apply:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/apply_empty_eco.tcl' empty_apply
pipeline-m1-grt:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_m1_design.mk do-grt
pipeline-m1-drt:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_m1_design.mk do-5_2_route do-5_3_fillcell do-5_route do-5_route.sdc

.PHONY: pipeline-6m7t-floorplan pipeline-6m7t-place pipeline-6m7t-cts pipeline-6m7t-grt pipeline-6m7t-drt pipeline-6m7t-extract pipeline-6m7t-check-extracted pipeline-6m7t-gds
pipeline-6m7t-floorplan pipeline-6m7t-place pipeline-6m7t-cts:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_6m7t_design.mk $(patsubst pipeline-6m7t-%,%,$@)
pipeline-6m7t-grt:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_6m7t_design.mk do-grt
pipeline-6m7t-drt:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_6m7t_design.mk do-5_2_route do-5_3_fillcell do-5_route do-5_route.sdc
pipeline-6m7t-extract:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_6m7t_design.mk --eval='physical_pipeline_6m7t_extract:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/extract_corner.tcl' physical_pipeline_6m7t_extract
pipeline-6m7t-check-extracted:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_6m7t_design.mk --eval='physical_pipeline_6m7t_extracted_check:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/check_extracted.tcl' physical_pipeline_6m7t_extracted_check
pipeline-6m7t-gds:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_6m7t_design.mk gds

.PHONY: pipeline-25-floorplan pipeline-25-place pipeline-25-cts pipeline-25-cts-direct pipeline-25-repair pipeline-25-grt pipeline-25-drt pipeline-25-route pipeline-25-extract pipeline-25-check-extracted pipeline-25-gds
pipeline-25-floorplan pipeline-25-place pipeline-25-cts:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_25u_design.mk $(patsubst pipeline-25-%,%,$@)
pipeline-25-cts-direct:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_25u_design.mk do-4_1_cts do-4_cts
pipeline-25-repair:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_25u_design.mk --eval='physical_pipeline_25_repair:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/repair_decoupled.tcl' physical_pipeline_25_repair
pipeline-25-grt:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_25u_design.mk do-grt
pipeline-25-drt:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_25u_design.mk do-5_2_route do-5_3_fillcell do-5_route do-5_route.sdc
pipeline-25-route:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_25u_design.mk do-route
pipeline-25-extract:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_25u_design.mk --eval='physical_pipeline_25_extract:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/extract_corner.tcl' physical_pipeline_25_extract
pipeline-25-check-extracted:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_25u_design.mk --eval='physical_pipeline_25_extracted_check:; @$$(OPENROAD_CMD) $(PROJECT_DIR)/physical/check_extracted.tcl' physical_pipeline_25_extracted_check
pipeline-25-gds:
	$(MAKE) -C $(FLOW_DIR) DESIGN_CONFIG=$(PROJECT_DIR)/physical/pipeline_25u_design.mk gds
