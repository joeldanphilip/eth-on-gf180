/*
 * Sky130 OpenRAM 2 kB pseudo-dual-port SRAM wrapper.
 *
 * Port 0 is 1RW and is used by the source clock.  Port 1 is read-only and is
 * used by the destination clock.  The physical build replaces the behavioral
 * model with the pre-characterized OpenRAM macro while simulation uses the
 * same vendor-provided model.
 */
`resetall
`timescale 1ns / 1ps
`default_nettype none

module sky130_sram_2kbyte_1rw1r_32x512_8_wrapper (
    input  wire        wr_clk,
    input  wire        wr_en,
    input  wire        wr_we,
    input  wire [3:0]  wr_wmask,
    input  wire [8:0]  wr_addr,
    input  wire [31:0] wr_din,
    output wire [31:0] wr_dout,
    input  wire        rd_clk,
    input  wire        rd_en,
    input  wire [8:0]  rd_addr,
    output wire [31:0] rd_dout
);

`ifdef SKY130_SRAM_PHYSICAL
    (* keep *) wire vccd1;
    (* keep *) wire vssd1;
    sky130_sram_2kbyte_1rw1r_32x512_8 macro (
        .vccd1 (vccd1),
        .vssd1 (vssd1),
        .clk0  (wr_clk),
        .csb0  (~wr_en),
        .web0  (~wr_we),
        .wmask0(wr_wmask),
        .addr0 (wr_addr),
        .din0  (wr_din),
        .dout0 (wr_dout),
        .clk1  (rd_clk),
        .csb1  (~rd_en),
        .addr1 (rd_addr),
        .dout1 (rd_dout)
    );
`else
    sky130_sram_2kbyte_1rw1r_32x512_8 #(.VERBOSE(0), .DELAY(0)) macro (
        .clk0  (wr_clk),
        .csb0  (~wr_en),
        .web0  (~wr_we),
        .wmask0(wr_wmask),
        .addr0 (wr_addr),
        .din0  (wr_din),
        .dout0 (wr_dout),
        .clk1  (rd_clk),
        .csb1  (~rd_en),
        .addr1 (rd_addr),
        .dout1 (rd_dout)
    );
`endif

endmodule

`ifdef SKY130_SRAM_PHYSICAL
(* blackbox *)
module sky130_sram_2kbyte_1rw1r_32x512_8 #(
    parameter VERBOSE = 0,
    parameter DELAY = 0
) (
    inout vccd1,
    inout vssd1,
    input clk0,
    input csb0,
    input web0,
    input [3:0] wmask0,
    input [8:0] addr0,
    input [31:0] din0,
    output [31:0] dout0,
    input clk1,
    input csb1,
    input [8:0] addr1,
    output [31:0] dout1
);
endmodule
`endif

`default_nettype wire
