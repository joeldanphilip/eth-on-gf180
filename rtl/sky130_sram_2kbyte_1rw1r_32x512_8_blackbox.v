`resetall
`timescale 1ns / 1ps
`default_nettype none

// Physical-only declaration.  The LEF/GDS/Liberty views provide the actual
// implementation; this module exists so mapped-netlist readers see the full
// power and signal pin list.
(* blackbox *)
module sky130_sram_2kbyte_1rw1r_32x512_8 (
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

`default_nettype wire
