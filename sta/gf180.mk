# Run from the project root: make -f sta/gf180.mk gf180
include Makefile
GF_PLATFORM := tools/ORFS/flow/platforms/gf180
GF_LIBBASE := $(GF_PLATFORM)/lib/gf180mcu_fd_sc_mcu9t5v0__
GF_BUILD := build/gf180
GF_ELAB ?= build/mac_elaborated.il
GF_TT ?= tt_025C_3v30
GF_SS ?= ss_125C_3v00
GF_FF ?= ff_n40C_3v60
GF_DELAY ?= 7000
GF_SIZED ?= 0
ifeq ($(GF_SIZED),1)
GF_DFF_OPTIONS := -dont_use *_1 -dont_use *_2
GF_ABC_OPTIONS := -dont_use *_1
endif
GF_BANK_RTL := $(filter-out $(R)/lib/axis/rtl/axis_async_fifo.v,$(RTL)) rtl/axis_async_fifo_banked.v
GF_CLOSURE_RTL := $(filter-out $(R)/rtl/axis_gmii_rx.v,$(GF_BANK_RTL)) rtl/axis_gmii_rx_lookahead.v
.PHONY: gf180 gf180-map gf180-banked gf180-sized gf180-5v gf180-closure gf180-registered gf180-registered-lowmux
build/gf180/banked_elaborated.il: $(GF_BANK_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -defer $(GF_BANK_RTL); chparam -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/banked_elaboration.log
gf180-banked:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_banked GF_ELAB=build/gf180/banked_elaborated.il gf180
gf180-sized:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_sized GF_ELAB=build/gf180/banked_elaborated.il GF_SIZED=1 gf180
gf180-5v:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_5v GF_ELAB=build/gf180/banked_elaborated.il GF_SIZED=1 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180
build/gf180/closure_elaborated.il: $(GF_CLOSURE_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/closure_elaboration.log
gf180-closure:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_closure GF_ELAB=build/gf180/closure_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180
build/gf180/registered_elaborated.il: $(GF_CLOSURE_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -D REGISTER_FULL_FLAGS -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/registered_elaboration.log
gf180-registered:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_registered GF_ELAB=build/gf180/registered_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180
.PHONY: gf180-elastic
build/gf180/elastic_elaborated.il: $(GF_CLOSURE_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -D REGISTER_FULL_FLAGS -D ELASTIC_READ -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/elastic_elaboration.log
gf180-elastic:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_elastic GF_ELAB=build/gf180/elastic_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180
.PHONY: gf180-fast-control
build/gf180/fast_elaborated.il: $(GF_CLOSURE_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -D REGISTER_FULL_FLAGS -D ELASTIC_READ -D FAST_CONTROL -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/fast_elaboration.log
gf180-fast-control:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_fast GF_ELAB=build/gf180/fast_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180
.PHONY: gf180-empty-control
build/gf180/empty_elaborated.il: $(GF_CLOSURE_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -D REGISTER_FULL_FLAGS -D ELASTIC_READ -D FAST_CONTROL -D REGISTER_EMPTY -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/empty_elaboration.log
gf180-empty-control:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_empty GF_ELAB=build/gf180/empty_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180
.PHONY: gf180-lookahead-control
build/gf180/lookahead_elaborated.il: $(GF_CLOSURE_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -D REGISTER_FULL_FLAGS -D ELASTIC_READ -D FAST_CONTROL -D REGISTER_EMPTY -D FULL_LOOKAHEAD -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/lookahead_elaboration.log
gf180-lookahead-control:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_lookahead GF_ELAB=build/gf180/lookahead_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180
.PHONY: gf180-write-ahead
build/gf180/write_ahead_elaborated.il: $(GF_CLOSURE_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -D REGISTER_FULL_FLAGS -D ELASTIC_READ -D FAST_CONTROL -D REGISTER_EMPTY -D FULL_LOOKAHEAD -D WRITE_AHEAD -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/write_ahead_elaboration.log
gf180-write-ahead:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_write_ahead GF_ELAB=build/gf180/write_ahead_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180
.PHONY: gf180-1g-2048
build/gf180/mac_2048_elaborated.il: $(GF_CLOSURE_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -D REGISTER_FULL_FLAGS -D ELASTIC_READ -D FAST_CONTROL -D REGISTER_EMPTY -D FULL_LOOKAHEAD -D WRITE_AHEAD -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_DEPTH 2048 -set RX_FIFO_DEPTH 2048 -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/mac_2048_elaboration.log
gf180-1g-2048:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_2048 GF_ELAB=build/gf180/mac_2048_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180
.PHONY: gf180-read-onehot
build/gf180/read_onehot_elaborated.il: $(GF_CLOSURE_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -D REGISTER_FULL_FLAGS -D ELASTIC_READ -D FAST_CONTROL -D REGISTER_EMPTY -D FULL_LOOKAHEAD -D WRITE_AHEAD -D READ_ONEHOT -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/read_onehot_elaboration.log
gf180-read-onehot:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_read_onehot GF_ELAB=build/gf180/read_onehot_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180

.PHONY: gf180-decoupled-read
build/gf180/decoupled_read_elaborated.il: $(GF_CLOSURE_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -D REGISTER_FULL_FLAGS -D ELASTIC_READ -D FAST_CONTROL -D REGISTER_EMPTY -D FULL_LOOKAHEAD -D WRITE_AHEAD -D READ_ONEHOT -D DECOUPLE_READ -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/decoupled_read_elaboration.log
gf180-decoupled-read:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_decoupled_read GF_ELAB=build/gf180/decoupled_read_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180-map build/gf180_decoupled_read/tt.lib build/gf180_decoupled_read/ff.lib

.PHONY: gf180-physical-pipeline
build/gf180/physical_pipeline_elaborated.il: $(GF_CLOSURE_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -D REGISTER_FULL_FLAGS -D ELASTIC_READ -D FAST_CONTROL -D REGISTER_EMPTY -D FULL_LOOKAHEAD -D WRITE_AHEAD -D READ_ONEHOT -D DECOUPLE_READ -D READ_BANK_ONEHOT -D PIPELINED_WRITE -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/physical_pipeline_elaboration.log
gf180-physical-pipeline:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_physical_pipeline GF_ELAB=build/gf180/physical_pipeline_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180-map build/gf180_physical_pipeline/tt.lib build/gf180_physical_pipeline/ff.lib

.PHONY: gf180-physical-pipeline-deep
build/gf180/physical_pipeline_deep_elaborated.il: $(GF_CLOSURE_RTL)
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -D REGISTER_FULL_FLAGS -D ELASTIC_READ -D FAST_CONTROL -D REGISTER_EMPTY -D FULL_LOOKAHEAD -D WRITE_AHEAD -D READ_ONEHOT -D DECOUPLE_READ -D READ_BANK_ONEHOT -D PIPELINED_WRITE -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_RAM_PIPELINE 3 -set RX_FIFO_RAM_PIPELINE 3 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/physical_pipeline_deep_elaboration.log
gf180-physical-pipeline-deep:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_physical_pipeline_deep GF_ELAB=build/gf180/physical_pipeline_deep_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180
build/gf180/registered_lowmux_elaborated.il: $(GF_CLOSURE_RTL) rtl/axis_async_fifo_banked.v
	mkdir -p build/gf180
	yosys -Q -T -p 'read_verilog -D SIMULATION -D ONEHOT_WRITE -D REGISTER_FULL_FLAGS -D LOW_MUX_ROWS -defer $(GF_CLOSURE_RTL); chparam -set TX_FIFO_RAM_PIPELINE 2 -set RX_FIFO_RAM_PIPELINE 2 eth_mac_1g_fifo; hierarchy -top eth_mac_1g_fifo; write_rtlil $@' > build/gf180/registered_lowmux_elaboration.log
gf180-registered-lowmux:
	$(MAKE) -f sta/gf180.mk GF_BUILD=build/gf180_registered_lowmux GF_ELAB=build/gf180/registered_lowmux_elaborated.il GF_SIZED=1 GF_DELAY=5000 GF_TT=tt_025C_5v00 GF_SS=ss_125C_4v50 GF_FF=ff_n40C_5v50 gf180
$(GF_BUILD)/tt.lib:
	mkdir -p $(GF_BUILD)
	gzip -dc $(GF_LIBBASE)$(GF_TT).lib.gz > $@
$(GF_BUILD)/ss.lib:
	mkdir -p $(GF_BUILD)
	gzip -dc $(GF_LIBBASE)$(GF_SS).lib.gz > $@
$(GF_BUILD)/ff.lib:
	mkdir -p $(GF_BUILD)
	gzip -dc $(GF_LIBBASE)$(GF_FF).lib.gz > $@
gf180-map: $(GF_BUILD)/mac_mapped.v
$(GF_BUILD)/mac_mapped.v: $(GF_ELAB) sta/gf180.mk sta/gf180.constr $(GF_BUILD)/ss.lib
	yosys -Q -T -p 'read_rtlil $(GF_ELAB); synth -top eth_mac_1g_fifo -flatten; dfflibmap -liberty $(GF_BUILD)/ss.lib $(GF_DFF_OPTIONS); abc -liberty $(GF_BUILD)/ss.lib -constr sta/gf180.constr -D $(GF_DELAY) $(GF_ABC_OPTIONS); read_liberty -lib $(GF_BUILD)/ss.lib; clean; rename -enumerate; check -assert; stat -liberty $(GF_BUILD)/ss.lib; write_rtlil $(GF_BUILD)/mac_mapped.il; write_json $(GF_BUILD)/mac_mapped.json; write_verilog -noattr -noexpr $@' > $(GF_BUILD)/mapping.log
gf180: gf180-map $(GF_BUILD)/tt.lib $(GF_BUILD)/ff.lib
	LIB_MAX=$(GF_BUILD)/ss.lib LIB_MIN=$(GF_BUILD)/ff.lib NETLIST=$(GF_BUILD)/mac_mapped.v HOLD_REPORT=$(GF_BUILD)/hold_endpoints.txt tools/OpenSTA/build/sta -exit sta/timing.tcl > $(GF_BUILD)/timing_baseline.log
	BUILD_DIR=$(GF_BUILD) HOLD_BUFFER=gf180mcu_fd_sc_mcu9t5v0__buf_1 HOLD_BUFFER_INPUT=I HOLD_FF_PREFIX=gf180mcu_fd_sc_mcu9t5v0__dff python3 scripts/fix_hold.py > $(GF_BUILD)/hold_eco.log
	yosys -Q -T -p 'read_json $(GF_BUILD)/mac_hold.json; hierarchy -top eth_mac_1g_fifo; check -assert; write_verilog -noattr -noexpr $(GF_BUILD)/mac_hold.v' > $(GF_BUILD)/hold_check.log
	LIB_MAX=$(GF_BUILD)/ss.lib LIB_MIN=$(GF_BUILD)/ff.lib NETLIST=$(GF_BUILD)/mac_hold.v HOLD_REPORT=$(GF_BUILD)/hold_remaining.txt tools/OpenSTA/build/sta -exit sta/timing.tcl > $(GF_BUILD)/timing_ss_ff.log
	LIB_MAX=$(GF_BUILD)/tt.lib LIB_MIN=$(GF_BUILD)/tt.lib NETLIST=$(GF_BUILD)/mac_hold.v HOLD_REPORT=$(GF_BUILD)/hold_tt.txt tools/OpenSTA/build/sta -exit sta/timing.tcl > $(GF_BUILD)/timing_tt.log
