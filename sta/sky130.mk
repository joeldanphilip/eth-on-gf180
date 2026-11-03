# Sky130HD STA for the 1RW1R OpenRAM-backed 1G MAC.
# Run from the project root: make -f sta/sky130.mk sky130
include Makefile

SKY_PLATFORM := tools/ORFS/flow/platforms/sky130hd
SKY_STD_LIB := $(SKY_PLATFORM)/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
SKY_MACRO_DIR ?= build/sky130_sram_macros/sky130_sram_2kbyte_1rw1r_32x512_8
SKY_MACRO_LIB := $(SKY_MACRO_DIR)/sky130_sram_2kbyte_1rw1r_32x512_8_TT_1p8V_25C.lib
SKY_MACRO_V := $(SKY_MACRO_DIR)/sky130_sram_2kbyte_1rw1r_32x512_8.v
SKY_BUILD ?= build/sky130
SKY_LIB := $(SKY_BUILD)/sky130_combined.lib
SKY_NETLIST := $(SKY_BUILD)/mac_mapped.v
SKY_RTL := vendor/verilog-ethernet/rtl/eth_mac_1g_fifo.v \
	vendor/verilog-ethernet/rtl/eth_mac_1g.v \
	rtl/axis_gmii_rx_lookahead.v \
	vendor/verilog-ethernet/rtl/axis_gmii_tx.v \
	vendor/verilog-ethernet/rtl/lfsr.v \
	vendor/verilog-ethernet/lib/axis/rtl/axis_adapter.v \
	vendor/verilog-ethernet/lib/axis/rtl/axis_async_fifo_adapter.v \
	rtl/axis_async_fifo_sky130_1rw1r_frame.v \
	rtl/sky130_sram_2kbyte_1rw1r_32x512_8.v

.PHONY: sky130 sky130-fetch sky130-map sky130-sta

sky130-fetch:
	./scripts/fetch_sky130_sram.sh

$(SKY_LIB): $(SKY_STD_LIB) $(SKY_MACRO_LIB)
	mkdir -p $(SKY_BUILD)
	cat $(SKY_STD_LIB) $(SKY_MACRO_LIB) > $@

$(SKY_NETLIST): $(SKY_RTL) $(SKY_LIB) sta/sky130.sdc
	mkdir -p $(SKY_BUILD)
	scripts/yosys -Q -T -p 'read_verilog -D SIMULATION -D SYNTHESIS -D SKY130_SRAM_PHYSICAL -D ONEHOT_WRITE $(SKY_RTL); hierarchy -top eth_mac_1g_fifo; synth -top eth_mac_1g_fifo -flatten; dfflibmap -liberty $(SKY_LIB); abc -liberty $(SKY_LIB) -constr sta/sky130.sdc -D 8000; read_liberty -lib $(SKY_LIB); clean; rename -enumerate; rename -unescape; check -assert; stat -liberty $(SKY_LIB); write_rtlil $(SKY_BUILD)/mac_mapped.il; write_verilog -noattr -noexpr $@' > $(SKY_BUILD)/mapping.log

sky130-map: $(SKY_NETLIST)

sky130-sta: $(SKY_NETLIST)
	LIB_MAX=$(SKY_STD_LIB) LIB_MIN=$(SKY_STD_LIB) LIB_AUX=$(SKY_MACRO_LIB) NETLIST=$(SKY_NETLIST) SDC_FILE=sta/sky130.sdc HOLD_REPORT=$(SKY_BUILD)/hold_endpoints.txt tools/OpenSTA/build/sta -exit sta/timing.tcl > $(SKY_BUILD)/timing.log

sky130: sky130-sta
