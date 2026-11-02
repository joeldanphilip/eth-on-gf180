OSS ?= /home/joelphilip/Documents/dft/oss-cad-suite
export PATH := $(CURDIR)/scripts:$(OSS)/bin:$(PATH)
R := vendor/verilog-ethernet
RTL := $(R)/rtl/eth_mac_1g_fifo.v $(R)/rtl/eth_mac_1g.v $(R)/rtl/axis_gmii_rx.v $(R)/rtl/axis_gmii_tx.v $(R)/rtl/lfsr.v $(R)/lib/axis/rtl/axis_adapter.v $(R)/lib/axis/rtl/axis_async_fifo.v $(R)/lib/axis/rtl/axis_async_fifo_adapter.v
.PHONY: test test-banked test-closure test-registered-lowmux synth formal formal-frame formal-banked formal-rx formal-onehot map sta sta-candidate sta-resize sta-check sta-nangate sta-baseline hold
test:
	.venv/bin/pytest -q $(R)/tb/eth_mac_1g_fifo/test_eth_mac_1g_fifo.py tests/test_multiclock.py
test-banked:
	BANKED_FIFO=1 TEST_FIFO_DEPTH=4096 .venv/bin/pytest -q tests/test_multiclock.py tests/test_banked_upstream.py
.PHONY: test-elastic formal-elastic
test-elastic:
	BANKED_FIFO=1 CLOSURE_RTL=1 REGISTERED_FIFO=1 ELASTIC_READ=1 TEST_FIFO_DEPTH=4096 .venv/bin/pytest -q tests/test_multiclock.py tests/test_banked_upstream.py
.PHONY: test-fast-control formal-fast-control formal-fast-invariant
test-fast-control:
	FAST_CONTROL=1 $(MAKE) test-elastic
formal-fast-control:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/fast_control formal/fast_control.sby
formal-fast-invariant:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/fast_invariant formal/fast_invariant.sby
.PHONY: test-empty-control formal-empty-control
test-empty-control:
	REGISTER_EMPTY=1 $(MAKE) test-fast-control
formal-empty-control:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/empty_control formal/empty_control.sby
.PHONY: formal-empty-invariant
formal-empty-invariant:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/empty_invariant formal/empty_invariant.sby
.PHONY: test-lookahead-control formal-lookahead-control
test-lookahead-control:
	FULL_LOOKAHEAD=1 $(MAKE) test-empty-control
formal-lookahead-control:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/lookahead_control formal/lookahead_control.sby
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/lookahead_invariant formal/lookahead_invariant.sby
.PHONY: test-write-ahead formal-write-ahead
test-write-ahead:
	WRITE_AHEAD=1 $(MAKE) test-lookahead-control
.PHONY: test-1g-2048
test-1g-2048:
	BANKED_FIFO=1 CLOSURE_RTL=1 REGISTERED_FIFO=1 ELASTIC_READ=1 FAST_CONTROL=1 REGISTER_EMPTY=1 FULL_LOOKAHEAD=1 WRITE_AHEAD=1 TEST_FIFO_DEPTH=2048 .venv/bin/pytest -q tests/test_multiclock.py tests/test_banked_upstream.py
formal-write-ahead:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/write_ahead formal/write_ahead.sby
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/write_ahead_invariant formal/write_ahead_invariant.sby
.PHONY: test-read-onehot formal-read-onehot
test-read-onehot:
	READ_ONEHOT=1 $(MAKE) test-write-ahead

.PHONY: test-decoupled-read formal-decoupled-read
test-decoupled-read:
	DECOUPLE_READ=1 $(MAKE) test-read-onehot
.PHONY: test-physical-pipeline
test-physical-pipeline:
	PHYSICAL_PIPELINE=1 $(MAKE) test-decoupled-read
.PHONY: formal-physical-pipeline formal-physical-pipeline-invariant
formal-physical-pipeline:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/physical_pipeline formal/physical_pipeline.sby
	$(MAKE) formal-physical-pipeline-invariant
.PHONY: formal-physical-pipeline-arbitrary
formal-physical-pipeline-arbitrary:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/physical_pipeline_arbitrary formal/physical_pipeline_arbitrary.sby
formal-physical-pipeline-invariant:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/physical_pipeline_invariant_v2 formal/physical_pipeline_invariant.sby
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/masked_mux formal/masked_mux.sby
formal-decoupled-read:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/decoupled_read formal/decoupled_read.sby
	$(MAKE) formal-decoupled-read-invariant
.PHONY: formal-decoupled-read-invariant
formal-decoupled-read-invariant:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/decoupled_read_invariant formal/decoupled_read_invariant.sby
.PHONY: formal-replication
formal-replication:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/replication_equivalence formal/replication_equivalence.sby
formal-read-onehot:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/read_onehot formal/read_onehot.sby
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/read_onehot_invariant formal/read_onehot_invariant.sby
formal-elastic:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/elastic_checked formal/elastic_fifo.sby
test-closure:
	BANKED_FIFO=1 CLOSURE_RTL=1 TEST_FIFO_DEPTH=4096 .venv/bin/pytest -q tests/test_multiclock.py tests/test_banked_upstream.py
test-registered-lowmux:
	BANKED_FIFO=1 CLOSURE_RTL=1 REGISTERED_FIFO=1 LOW_MUX_ROWS=1 TEST_FIFO_DEPTH=4096 .venv/bin/pytest -q tests/test_multiclock.py tests/test_banked_upstream.py
build/mac_elaborated.il: $(RTL)
	mkdir -p build
	yosys -Q -T -p 'read_verilog -D SIMULATION -defer $(RTL); hierarchy -top eth_mac_1g_fifo; write_rtlil build/mac_elaborated.il' > build/elaboration.log
synth: build/mac_elaborated.il
	yosys -Q -T -p 'read_rtlil build/mac_elaborated.il; synth -top eth_mac_1g_fifo; check -assert; stat; write_verilog -noattr build/mac_generic.v' > build/synthesis.log
formal:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/fifo formal/fifo.sby
formal-frame:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/frame_fifo formal/frame_fifo.sby
formal-banked:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/banked_equiv formal/banked_equivalence.sby
formal-rx:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/rx_induction formal/rx_induction.sby
formal-onehot:
	/usr/bin/python3 tools/sby/sbysrc/sby.py -f --prefix build/onehot_full formal/onehot_invariant_full.sby
map: build/mac_mapped.v
build/mac_mapped.v: build/mac_elaborated.il Makefile sta/abc.constr
	mkdir -p build
	yosys -Q -T -p 'read_rtlil build/mac_elaborated.il; synth -top eth_mac_1g_fifo -flatten; dfflibmap -liberty tools/ORFS/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib; abc -liberty tools/ORFS/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib -constr sta/abc.constr -D 7000; read_liberty -lib tools/ORFS/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib; clean; write_rtlil build/mac_mapped.il; check -assert; stat -liberty tools/ORFS/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib; write_verilog -noattr -noexpr build/mac_mapped.v' > build/mapping.log
sta-baseline: map
	yosys -Q -T -p 'read_rtlil build/mac_mapped.il; rename -enumerate; write_json build/mac_mapped.json; write_verilog -noattr -noexpr build/mac_mapped.v' > build/export_json.log
	tools/OpenSTA/build/sta -exit sta/timing.tcl > build/timing.log
sta: sta-1g-closed
.PHONY: sta-gf180-3v3 sta-1g-closed sta-close-1g verify-1g
sta-gf180-3v3:
	$(MAKE) -f sta/gf180.mk gf180-sized
CLOSED_PROFILE := build/gf180_read_onehot_finish
sta-1g-closed: $(CLOSED_PROFILE)/mac_resized.v
	LIB_MAX=$(CLOSED_PROFILE)/ss.lib LIB_MIN=$(CLOSED_PROFILE)/ff.lib NETLIST=$(CLOSED_PROFILE)/mac_resized.v HOLD_REPORT=$(CLOSED_PROFILE)/hold_final.txt tools/OpenSTA/build/sta -exit sta/timing.tcl > $(CLOSED_PROFILE)/timing_ss_ff.log
	LIB_MAX=$(CLOSED_PROFILE)/tt.lib LIB_MIN=$(CLOSED_PROFILE)/tt.lib NETLIST=$(CLOSED_PROFILE)/mac_resized.v HOLD_REPORT=$(CLOSED_PROFILE)/hold_final_tt.txt tools/OpenSTA/build/sta -exit sta/timing.tcl > $(CLOSED_PROFILE)/timing_tt.log
	python3 scripts/check_timing.py $(CLOSED_PROFILE)/timing_ss_ff.log --require-closure > $(CLOSED_PROFILE)/closure_ss_ff.json
	python3 scripts/check_timing.py $(CLOSED_PROFILE)/timing_tt.log --require-closure > $(CLOSED_PROFILE)/closure_tt.json
# Rebuild from RTL, then replay two stages of hold-safe drive-grade search.
sta-close-1g:
	$(MAKE) -f sta/gf180.mk gf180-read-onehot
	RESIZE_PROFILE=build/gf180_read_onehot RESIZE_SECONDS=180 RESIZE_ROUNDS=200 RESIZE_GREEDY=1 RESIZE_EXHAUSTIVE=1 RESIZE_BIDIRECTIONAL=1 tools/OpenSTA/build/sta -exit sta/resize.tcl > build/gf180_read_onehot/resize.log
	python3 scripts/replay_sizing.py build/gf180_read_onehot --allow-downsize > build/gf180_read_onehot/resize_replay.log
	yosys -Q -T -p 'read_json build/gf180_read_onehot/mac_resized.json; hierarchy -top eth_mac_1g_fifo; check -assert; write_verilog -noattr -noexpr build/gf180_read_onehot/mac_resized.v' > build/gf180_read_onehot/resized_structural.log
	mkdir -p $(CLOSED_PROFILE)
	cp build/gf180_read_onehot/ss.lib build/gf180_read_onehot/ff.lib build/gf180_read_onehot/tt.lib $(CLOSED_PROFILE)/
	cp build/gf180_read_onehot/mac_resized.json $(CLOSED_PROFILE)/mac_hold.json
	cp build/gf180_read_onehot/mac_resized.v $(CLOSED_PROFILE)/mac_hold.v
	RESIZE_PROFILE=$(CLOSED_PROFILE) RESIZE_SECONDS=180 RESIZE_ROUNDS=200 RESIZE_GREEDY=1 RESIZE_EXHAUSTIVE=1 RESIZE_BIDIRECTIONAL=1 RESIZE_SIDE_LOADS=1 RESIZE_TARGET_NS=0.05 tools/OpenSTA/build/sta -exit sta/resize.tcl > $(CLOSED_PROFILE)/resize.log
	python3 scripts/replay_sizing.py $(CLOSED_PROFILE) --allow-downsize > $(CLOSED_PROFILE)/resize_replay.log
	yosys -Q -T -p 'read_json $(CLOSED_PROFILE)/mac_resized.json; hierarchy -top eth_mac_1g_fifo; check -assert; write_verilog -noattr -noexpr $(CLOSED_PROFILE)/mac_resized.v' > $(CLOSED_PROFILE)/resized_structural.log
	$(MAKE) sta-1g-closed
verify-1g: test-read-onehot formal-read-onehot sta-1g-closed
sta-candidate:
	$(MAKE) -f sta/gf180.mk gf180-closure
sta-resize: sta-candidate
	tools/OpenSTA/build/sta -exit sta/resize.tcl > build/gf180_closure/resize.log
	python3 scripts/replay_sizing.py build/gf180_closure > build/gf180_closure/resize_replay.log
	yosys -Q -T -p 'read_json build/gf180_closure/mac_resized.json; hierarchy -top eth_mac_1g_fifo; check -assert; write_verilog -noattr -noexpr build/gf180_closure/mac_resized.v' > build/gf180_closure/resized_structural.log
	LIB_MAX=build/gf180_closure/ss.lib LIB_MIN=build/gf180_closure/ff.lib NETLIST=build/gf180_closure/mac_resized.v HOLD_REPORT=build/gf180_closure/hold_resized.txt tools/OpenSTA/build/sta -exit sta/timing.tcl > build/gf180_closure/timing_resized_ss_ff.log
	LIB_MAX=build/gf180_closure/tt.lib LIB_MIN=build/gf180_closure/tt.lib NETLIST=build/gf180_closure/mac_resized.v HOLD_REPORT=build/gf180_closure/hold_resized_tt.txt tools/OpenSTA/build/sta -exit sta/timing.tcl > build/gf180_closure/timing_resized_tt.log
sta-check: sta
	python3 scripts/check_timing.py $(CLOSED_PROFILE)/timing_ss_ff.log --require-closure
sta-nangate: hold
hold: sta-baseline
	python3 scripts/fix_hold.py > build/hold_eco.log
	yosys -Q -T -p 'read_json build/mac_hold.json; hierarchy -top eth_mac_1g_fifo; check -assert; write_verilog -noattr -noexpr build/mac_hold.v' > build/hold_check.log
	NETLIST=build/mac_hold.v HOLD_REPORT=build/hold_remaining.txt tools/OpenSTA/build/sta -exit sta/timing.tcl > build/timing_hold.log
