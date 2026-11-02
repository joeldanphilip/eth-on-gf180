/*

Copyright (c) 2014-2023 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream asynchronous FIFO
 */
module axis_async_fifo #
(
    // FIFO depth in words
    // KEEP_WIDTH words per cycle if KEEP_ENABLE set
    // Rounded up to nearest power of 2 cycles
    parameter DEPTH = 4096,
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 8,
    // Propagate tkeep signal
    // If disabled, tkeep assumed to be 1'b1
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = ((DATA_WIDTH+7)/8),
    // Propagate tlast signal
    parameter LAST_ENABLE = 1,
    // Propagate tid signal
    parameter ID_ENABLE = 0,
    // tid signal width
    parameter ID_WIDTH = 8,
    // Propagate tdest signal
    parameter DEST_ENABLE = 0,
    // tdest signal width
    parameter DEST_WIDTH = 8,
    // Propagate tuser signal
    parameter USER_ENABLE = 1,
    // tuser signal width
    parameter USER_WIDTH = 1,
    // number of RAM pipeline registers
    parameter RAM_PIPELINE = 1,
    // use output FIFO
    // When set, the RAM read enable and pipeline clock enables are removed
    parameter OUTPUT_FIFO_ENABLE = 0,
    // Frame FIFO mode - operate on frames instead of cycles
    // When set, m_axis_tvalid will not be deasserted within a frame
    // Requires LAST_ENABLE set
    parameter FRAME_FIFO = 0,
    // tuser value for bad frame marker
    parameter USER_BAD_FRAME_VALUE = 1'b1,
    // tuser mask for bad frame marker
    parameter USER_BAD_FRAME_MASK = 1'b1,
    // Drop frames larger than FIFO
    // Requires FRAME_FIFO set
    parameter DROP_OVERSIZE_FRAME = FRAME_FIFO,
    // Drop frames marked bad
    // Requires FRAME_FIFO and DROP_OVERSIZE_FRAME set
    parameter DROP_BAD_FRAME = 0,
    // Drop incoming frames when full
    // When set, s_axis_tready is always asserted
    // Requires FRAME_FIFO and DROP_OVERSIZE_FRAME set
    parameter DROP_WHEN_FULL = 0,
    // Mark incoming frames as bad frames when full
    // When set, s_axis_tready is always asserted
    // Requires FRAME_FIFO to be clear
    parameter MARK_WHEN_FULL = 0,
    // Enable pause request input
    parameter PAUSE_ENABLE = 0,
    // Pause between frames
    parameter FRAME_PAUSE = FRAME_FIFO
)
(
    /*
     * AXI input
     */
    input  wire                   s_clk,
    input  wire                   s_rst,
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,
    input  wire [ID_WIDTH-1:0]    s_axis_tid,
    input  wire [DEST_WIDTH-1:0]  s_axis_tdest,
    input  wire [USER_WIDTH-1:0]  s_axis_tuser,

    /*
     * AXI output
     */
    input  wire                   m_clk,
    input  wire                   m_rst,
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]  m_axis_tkeep,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast,
    output wire [ID_WIDTH-1:0]    m_axis_tid,
    output wire [DEST_WIDTH-1:0]  m_axis_tdest,
    output wire [USER_WIDTH-1:0]  m_axis_tuser,

    /*
     * Pause
     */
    input  wire                   s_pause_req,
    output wire                   s_pause_ack,
    input  wire                   m_pause_req,
    output wire                   m_pause_ack,

    /*
     * Status
     */
    output wire [$clog2(DEPTH):0] s_status_depth,
    output wire [$clog2(DEPTH):0] s_status_depth_commit,
    output wire                   s_status_overflow,
    output wire                   s_status_bad_frame,
    output wire                   s_status_good_frame,
    output wire [$clog2(DEPTH):0] m_status_depth,
    output wire [$clog2(DEPTH):0] m_status_depth_commit,
    output wire                   m_status_overflow,
    output wire                   m_status_bad_frame,
    output wire                   m_status_good_frame
);

parameter ADDR_WIDTH = (KEEP_ENABLE && KEEP_WIDTH > 1) ? $clog2(DEPTH/KEEP_WIDTH) : $clog2(DEPTH);

parameter OUTPUT_FIFO_ADDR_WIDTH = RAM_PIPELINE < 2 ? 3 : $clog2(RAM_PIPELINE*2+7);

// check configuration
initial begin
    if (FRAME_FIFO && !LAST_ENABLE) begin
        $error("Error: FRAME_FIFO set requires LAST_ENABLE set (instance %m)");
        $finish;
    end

    if (DROP_OVERSIZE_FRAME && !FRAME_FIFO) begin
        $error("Error: DROP_OVERSIZE_FRAME set requires FRAME_FIFO set (instance %m)");
        $finish;
    end

    if (DROP_BAD_FRAME && !(FRAME_FIFO && DROP_OVERSIZE_FRAME)) begin
        $error("Error: DROP_BAD_FRAME set requires FRAME_FIFO and DROP_OVERSIZE_FRAME set (instance %m)");
        $finish;
    end

    if (DROP_WHEN_FULL && !(FRAME_FIFO && DROP_OVERSIZE_FRAME)) begin
        $error("Error: DROP_WHEN_FULL set requires FRAME_FIFO and DROP_OVERSIZE_FRAME set (instance %m)");
        $finish;
    end

    if ((DROP_BAD_FRAME || MARK_WHEN_FULL) && (USER_BAD_FRAME_MASK & {USER_WIDTH{1'b1}}) == 0) begin
        $error("Error: Invalid USER_BAD_FRAME_MASK value (instance %m)");
        $finish;
    end

    if (MARK_WHEN_FULL && FRAME_FIFO) begin
        $error("Error: MARK_WHEN_FULL is not compatible with FRAME_FIFO (instance %m)");
        $finish;
    end

    if (MARK_WHEN_FULL && !LAST_ENABLE) begin
        $error("Error: MARK_WHEN_FULL set requires LAST_ENABLE set (instance %m)");
        $finish;
    end
end

localparam KEEP_OFFSET = DATA_WIDTH;
localparam LAST_OFFSET = KEEP_OFFSET + (KEEP_ENABLE ? KEEP_WIDTH : 0);
localparam ID_OFFSET   = LAST_OFFSET + (LAST_ENABLE ? 1          : 0);
localparam DEST_OFFSET = ID_OFFSET   + (ID_ENABLE   ? ID_WIDTH   : 0);
localparam USER_OFFSET = DEST_OFFSET + (DEST_ENABLE ? DEST_WIDTH : 0);
localparam WIDTH       = USER_OFFSET + (USER_ENABLE ? USER_WIDTH : 0);

// Physical variant: decouple the wide bank/group pipeline from downstream
// ready using the existing output queue. Main frame-storage depth is unchanged.
`ifdef DECOUPLE_READ
localparam USE_OUTPUT_FIFO = 1;
`else
localparam USE_OUTPUT_FIFO = OUTPUT_FIFO_ENABLE;
`endif

function [ADDR_WIDTH:0] bin2gray(input [ADDR_WIDTH:0] b);
    bin2gray = b ^ (b >> 1);
endfunction

function [ADDR_WIDTH:0] gray2bin(input [ADDR_WIDTH:0] g);
    integer i;
    for (i = 0; i <= ADDR_WIDTH; i = i + 1) begin
        gray2bin[i] = ^(g >> i);
    end
endfunction

reg [ADDR_WIDTH:0] wr_ptr_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_commit_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_gray_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_sync_commit_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_gray_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_conv_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_conv_reg = {ADDR_WIDTH+1{1'b0}};

reg [ADDR_WIDTH:0] wr_ptr_temp;
reg [ADDR_WIDTH:0] rd_ptr_temp;

(* SHREG_EXTRACT = "NO" *)
reg [ADDR_WIDTH:0] wr_ptr_gray_sync1_reg = {ADDR_WIDTH+1{1'b0}};
(* SHREG_EXTRACT = "NO" *)
reg [ADDR_WIDTH:0] wr_ptr_gray_sync2_reg = {ADDR_WIDTH+1{1'b0}};
(* SHREG_EXTRACT = "NO" *)
reg [ADDR_WIDTH:0] wr_ptr_commit_sync_reg = {ADDR_WIDTH+1{1'b0}};
(* SHREG_EXTRACT = "NO" *)
reg [ADDR_WIDTH:0] rd_ptr_gray_sync1_reg = {ADDR_WIDTH+1{1'b0}};
(* SHREG_EXTRACT = "NO" *)
reg [ADDR_WIDTH:0] rd_ptr_gray_sync2_reg = {ADDR_WIDTH+1{1'b0}};

reg wr_ptr_update_valid_reg = 1'b0;
reg wr_ptr_update_reg = 1'b0;
(* SHREG_EXTRACT = "NO" *)
reg wr_ptr_update_sync1_reg = 1'b0;
(* SHREG_EXTRACT = "NO" *)
reg wr_ptr_update_sync2_reg = 1'b0;
(* SHREG_EXTRACT = "NO" *)
reg wr_ptr_update_sync3_reg = 1'b0;
(* SHREG_EXTRACT = "NO" *)
reg wr_ptr_update_ack_sync1_reg = 1'b0;
(* SHREG_EXTRACT = "NO" *)
reg wr_ptr_update_ack_sync2_reg = 1'b0;

(* SHREG_EXTRACT = "NO" *)
reg s_rst_sync1_reg = 1'b1;
(* SHREG_EXTRACT = "NO" *)
reg s_rst_sync2_reg = 1'b1;
(* SHREG_EXTRACT = "NO" *)
reg s_rst_sync3_reg = 1'b1;
(* SHREG_EXTRACT = "NO" *)
reg m_rst_sync1_reg = 1'b1;
(* SHREG_EXTRACT = "NO" *)
reg m_rst_sync2_reg = 1'b1;
(* SHREG_EXTRACT = "NO" *)
reg m_rst_sync3_reg = 1'b1;

(* ramstyle = "no_rw_check" *)
reg [WIDTH-1:0] mem[(2**ADDR_WIDTH)-1:0];
reg mem_read_data_valid_reg = 1'b0;

(* shreg_extract = "no" *)
reg [WIDTH-1:0] m_axis_pipe_reg[RAM_PIPELINE+1-1:0];
reg [RAM_PIPELINE+1-1:0] m_axis_tvalid_pipe_reg = 0;

// Project variant: use the existing first two pipeline slots to register a
// banked read and a partial bank selection. The externally visible pipeline
// latency and all pointer/valid control are unchanged for a given RAM_PIPELINE.
`ifdef LOW_MUX_ROWS
// Timing candidate: eight words per bank bounds the local read mux at 8:1.
// The bank count increases, but the FIFO depth, pointer protocol, and output
// pipeline contract are unchanged.
localparam BANK_ROW_BITS = ADDR_WIDTH < 3 ? ADDR_WIDTH : 3;
`else
localparam BANK_ROW_BITS = ADDR_WIDTH < 4 ? ADDR_WIDTH : 4;
`endif
`ifdef LOW_MUX_ROWS
`define BANKED_READ_PREFETCH
`endif
localparam BANK_BITS = ADDR_WIDTH-BANK_ROW_BITS;
localparam BANK_COUNT = 1 << BANK_BITS;
localparam MID_BITS = BANK_BITS > 4 ? 4 : BANK_BITS;
localparam GROUP_BITS = BANK_BITS-MID_BITS;
localparam GROUP_COUNT = 1 << GROUP_BITS;
localparam BANK_SEL_WIDTH = BANK_BITS > 0 ? BANK_BITS : 1;
localparam GROUP_SEL_WIDTH = GROUP_BITS > 0 ? GROUP_BITS : 1;
localparam USE_BANKED = RAM_PIPELINE >= 2 && ADDR_WIDTH > 4;
`ifdef PIPELINED_WRITE
localparam USE_WRITE_PIPELINE = USE_BANKED && FRAME_FIFO;
`else
localparam USE_WRITE_PIPELINE = 0;
`endif
`ifdef ONEHOT_WRITE
localparam USE_ONEHOT_WRITE = USE_BANKED;
`else
localparam USE_ONEHOT_WRITE = 0;
`endif
`ifdef REGISTER_FULL_FLAGS
localparam USE_REGISTERED_FULL = 1;
`else
localparam USE_REGISTERED_FULL = 0;
`endif
reg full_reg=0, full_wr_reg=0;
`ifdef FORMAL
`ifdef FULL_LOOKAHEAD
reg full_reference_reg = 0;
always @* if (USE_REGISTERED_FULL) assert(full_reg == full_reference_reg);
`endif
`endif
`ifdef WRITE_AHEAD
// Redundant state keeps the increment off the full/decode decision paths.
reg [ADDR_WIDTH:0] wr_increment_reg = 1;
wire [ADDR_WIDTH:0] wr_increment = wr_increment_reg;
`ifdef FORMAL
always @* assert(wr_increment_reg == ((wr_ptr_reg + 1) & {ADDR_WIDTH+1{1'b1}}));
`endif
`else
wire [ADDR_WIDTH:0] wr_increment = wr_ptr_reg + 1;
`endif
`ifdef FAST_CONTROL
wire full_wr_increment = wr_increment == (wr_ptr_commit_reg ^ {1'b1, {ADDR_WIDTH{1'b0}}});
`ifdef FULL_LOOKAHEAD
wire full_increment = (wr_increment ^ (wr_increment >> 1)) ==
    (rd_ptr_gray_sync2_reg ^ {2'b11, {ADDR_WIDTH-1{1'b0}}});
wire full_commit = (wr_ptr_commit_reg ^ (wr_ptr_commit_reg >> 1)) ==
    (rd_ptr_gray_sync2_reg ^ {2'b11, {ADDR_WIDTH-1{1'b0}}});
wire full_zero = 0 == (rd_ptr_gray_sync2_reg ^ {2'b11, {ADDR_WIDTH-1{1'b0}}});
`endif
`endif
localparam ROW_COUNT = 1 << BANK_ROW_BITS;
reg [BANK_COUNT-1:0] wr_bank_onehot = {{BANK_COUNT-1{1'b0}},1'b1};
reg [ROW_COUNT-1:0] wr_row_onehot = {{ROW_COUNT-1{1'b0}},1'b1};
task update_write_decode;
    input [ADDR_WIDTH:0] ptr;
    begin
`ifdef WRITE_AHEAD
        wr_increment_reg <= ptr + 1;
`endif
        if (USE_ONEHOT_WRITE) begin
            wr_bank_onehot <= {{BANK_COUNT-1{1'b0}},1'b1} << ((ptr & ((1 << ADDR_WIDTH)-1)) >> BANK_ROW_BITS);
            wr_row_onehot <= {{ROW_COUNT-1{1'b0}},1'b1} << (ptr & (ROW_COUNT-1));
        end
        if (USE_REGISTERED_FULL) begin
`ifdef FORMAL
`ifdef FULL_LOOKAHEAD
            full_reference_reg <= ((ptr ^ (ptr >> 1)) ==
                (rd_ptr_gray_sync2_reg ^ {2'b11, {ADDR_WIDTH-1{1'b0}}}));
`endif
`endif
`ifdef FULL_LOOKAHEAD
            if (!FRAME_FIFO)
`endif
                full_reg <= ((ptr ^ (ptr >> 1)) == (rd_ptr_gray_sync2_reg ^ {2'b11, {ADDR_WIDTH-1{1'b0}}}));
`ifdef FAST_CONTROL
            if (!FRAME_FIFO)
`endif
                full_wr_reg <= (ptr == (wr_ptr_commit_reg ^ {1'b1, {ADDR_WIDTH{1'b0}}}));
        end
    end
endtask
`ifdef FORMAL
always @* if (USE_ONEHOT_WRITE) begin
    assert(wr_bank_onehot == ({{BANK_COUNT-1{1'b0}},1'b1} << (wr_ptr_reg[ADDR_WIDTH-1:0] >> BANK_ROW_BITS)));
    assert(wr_row_onehot == ({{ROW_COUNT-1{1'b0}},1'b1} << wr_ptr_reg[BANK_ROW_BITS-1:0]));
end
always @* if (USE_REGISTERED_FULL) assert(full_wr_reg == full_wr_raw);
`endif
reg [WIDTH-1:0] bank_read_data [0:BANK_COUNT-1];
reg [WIDTH-1:0] group_read_data [0:GROUP_COUNT-1];
reg [BANK_SEL_WIDTH-1:0] bank_select;
reg [GROUP_SEL_WIDTH-1:0] group_select;
`ifdef READ_BANK_ONEHOT
reg [(1 << MID_BITS)-1:0] bank_select_onehot_reg = 1;
reg [GROUP_COUNT-1:0] group_select_onehot_reg = 1;
reg [WIDTH-1:0] selected_bank_group [0:GROUP_COUNT-1];
`endif
`ifdef ELASTIC_READ
// Independent address stage. Its ready signal includes its own occupancy;
// downstream bubbles must never overwrite a pending address under a stall.
reg [BANK_ROW_BITS-1:0] elastic_row_reg;
`ifdef READ_ONEHOT
reg [ROW_COUNT-1:0] elastic_row_onehot_reg = 1;
`ifdef FORMAL
always @* if (elastic_valid_reg)
    assert(elastic_row_onehot_reg == ({{ROW_COUNT-1{1'b0}},1'b1} << elastic_row_reg));
`endif
`endif
reg [BANK_SEL_WIDTH-1:0] elastic_bank_reg;
reg elastic_valid_reg = 0;
reg [ADDR_WIDTH:0] elastic_fetch_ptr_reg = 0;
`ifdef FAST_CONTROL
localparam FETCH_SPLIT = ADDR_WIDTH > 4 ? 4 : 1;
reg fetch_carry_reg = 0;
wire [ADDR_WIDTH:0] elastic_fetch_increment = {
    (elastic_fetch_ptr_reg[ADDR_WIDTH:FETCH_SPLIT] + fetch_carry_reg),
    (elastic_fetch_ptr_reg[FETCH_SPLIT-1:0] + {{FETCH_SPLIT-1{1'b0}},1'b1})};
`ifdef FORMAL
always @* assert(fetch_carry_reg == (&elastic_fetch_ptr_reg[FETCH_SPLIT-1:0]));
`endif
`else
wire [ADDR_WIDTH:0] elastic_fetch_increment = elastic_fetch_ptr_reg + 1;
`endif
wire elastic_empty_raw = FRAME_FIFO ? elastic_fetch_ptr_reg == wr_ptr_commit_sync_reg :
    ((elastic_fetch_ptr_reg ^ (elastic_fetch_ptr_reg >> 1)) == wr_ptr_gray_sync2_reg);
`ifdef REGISTER_EMPTY
reg elastic_empty_reg = 1;
wire elastic_empty = elastic_empty_reg;
`ifdef FORMAL
always @* if (USE_BANKED) assert(elastic_empty_reg == elastic_empty_raw);
`endif
wire [ADDR_WIDTH:0] elastic_visible_commit = FRAME_FIFO ?
    ((wr_ptr_update_sync2_reg ^ wr_ptr_update_sync3_reg) ? wr_ptr_sync_commit_reg : wr_ptr_commit_sync_reg) :
    wr_ptr_gray_sync1_reg;
wire elastic_empty_hold = FRAME_FIFO ? elastic_fetch_ptr_reg == elastic_visible_commit :
    ((elastic_fetch_ptr_reg ^ (elastic_fetch_ptr_reg >> 1)) == elastic_visible_commit);
wire elastic_empty_increment = FRAME_FIFO ? elastic_fetch_increment == elastic_visible_commit :
    ((elastic_fetch_increment ^ (elastic_fetch_increment >> 1)) == elastic_visible_commit);
`else
wire elastic_empty = elastic_empty_raw;
`endif
wire elastic_data_ready = m_axis_tready_pipe || ~m_axis_tvalid_pipe_reg;
wire elastic_address_ready = !elastic_valid_reg || elastic_data_ready;
`endif
`ifdef BANKED_READ_PREFETCH
// Candidate-only prefetch state moves the pointer-to-row-mux path across a
// register while retaining the same banked storage and output ordering.
reg [BANK_ROW_BITS-1:0] bank_read_row;
reg [BANK_SEL_WIDTH-1:0] bank_read_bank;
reg bank_read_valid;
`endif
integer group_index;
wire bank_write_enable = FRAME_FIFO ?
    (s_axis_tready && s_axis_tvalid && !((full && DROP_WHEN_FULL) || (full_wr && DROP_OVERSIZE_FRAME) || drop_frame_reg)) :
    (s_axis_tready && s_axis_tvalid ?
        (drop_frame_reg && LAST_ENABLE ? (s_axis_tlast && !full && mark_frame_reg && MARK_WHEN_FULL) :
         !((full || mark_frame_reg) && MARK_WHEN_FULL)) :
        (!full && !drop_frame_reg && mark_frame_reg && MARK_WHEN_FULL));
genvar bank;
reg [BANK_COUNT-1:0] write_bank_pending_reg = 0;
reg [ROW_COUNT-1:0] write_row_pending_reg = 0;
reg [WIDTH-1:0] write_data_pending_reg;
reg write_update_pending_reg = 0;
generate if (USE_WRITE_PIPELINE) begin : write_pipeline
    always @(posedge s_clk) begin
        write_data_pending_reg <= s_axis;
        write_row_pending_reg <= {{ROW_COUNT-1{1'b0}},1'b1} << wr_ptr_reg[BANK_ROW_BITS-1:0];
        write_bank_pending_reg <= ({{BANK_COUNT-1{1'b0}},1'b1} << (wr_ptr_reg[ADDR_WIDTH-1:0] >> BANK_ROW_BITS)) & {BANK_COUNT{bank_write_enable}};
        write_update_pending_reg <= wr_ptr_update_reg;
        if (s_rst || s_rst_sync3_reg) begin
            write_bank_pending_reg <= 0;
            write_update_pending_reg <= 0;
        end
    end
`ifdef FORMAL
    reg past_valid = 0;
    reg [ADDR_WIDTH-1:0] sampled_write_addr;
    reg [WIDTH-1:0] sampled_write_data;
    reg sampled_write_enable;
    reg sampled_write_update;
    reg sampled_write_reset;
    always @(posedge s_clk) begin
        past_valid <= 1;
        sampled_write_addr <= wr_ptr_reg[ADDR_WIDTH-1:0];
        sampled_write_data <= s_axis;
        sampled_write_enable <= bank_write_enable;
        sampled_write_update <= wr_ptr_update_reg;
        sampled_write_reset <= s_rst || s_rst_sync3_reg;
    end
    // Check alignment on every formal step, including clock stuttering.
    // Edge-only $past assertions leave an unconstrained history in induction
    // when there has not been a source-clock edge within the induction window.
    always @* begin
        if (past_valid) begin
            assert(write_data_pending_reg == sampled_write_data);
            assert(write_row_pending_reg == ({{ROW_COUNT-1{1'b0}},1'b1} << sampled_write_addr[BANK_ROW_BITS-1:0]));
            assert(write_update_pending_reg == (sampled_write_reset ? 1'b0 : sampled_write_update));
            assert(write_bank_pending_reg == (sampled_write_reset ? {BANK_COUNT{1'b0}} :
                (({{BANK_COUNT-1{1'b0}},1'b1} << (sampled_write_addr >> BANK_ROW_BITS)) & {BANK_COUNT{sampled_write_enable}})));
        end
    end
`endif
end endgenerate
wire wr_ptr_update_visible = USE_WRITE_PIPELINE ? write_update_pending_reg : wr_ptr_update_reg;

`ifdef READ_BANK_ONEHOT
genvar select_group;
generate for (select_group=0; select_group<GROUP_COUNT; select_group=select_group+1) begin : bank_select_mask
    integer lane;
    reg [WIDTH-1:0] selected;
    assign selected_bank_group[select_group] = selected;
    always @* begin
        selected = 0;
        for (lane=0; lane<(1 << MID_BITS); lane=lane+1)
            selected = selected |
                (bank_read_data[(select_group << MID_BITS)+lane] & {WIDTH{bank_select_onehot_reg[lane]}});
    end
end endgenerate
`ifdef FORMAL
generate if (USE_BANKED) begin : bank_select_invariant
    always @* begin
        if (m_axis_tvalid_pipe_reg[0])
            assert(bank_select_onehot_reg == ({{(1 << MID_BITS)-1{1'b0}},1'b1} << (bank_select & ((1 << MID_BITS)-1))));
        if (m_axis_tvalid_pipe_reg[1])
            assert(group_select_onehot_reg == ({{GROUP_COUNT-1{1'b0}},1'b1} << group_select));
    end
end endgenerate
`endif
`endif
generate if (USE_BANKED) begin : banked_read_mux
    for (bank=0; bank<BANK_COUNT; bank=bank+1) begin : storage
        reg [WIDTH-1:0] words [0:(1 << BANK_ROW_BITS)-1];
        if (USE_WRITE_PIPELINE) begin : registered_write
            integer write_row;
            always @(posedge s_clk)
                if (write_bank_pending_reg[bank])
                    for (write_row=0; write_row<ROW_COUNT; write_row=write_row+1)
                        if (write_row_pending_reg[write_row]) words[write_row] <= write_data_pending_reg;
        end else if (USE_ONEHOT_WRITE) begin : predecoded_write
            integer write_row;
            always @(posedge s_clk)
                if (bank_write_enable && wr_bank_onehot[bank])
                    for (write_row=0; write_row<ROW_COUNT; write_row=write_row+1)
                        if (wr_row_onehot[write_row]) words[write_row] <= s_axis;
        end else begin : indexed_write
            always @(posedge s_clk)
                if (bank_write_enable && (wr_ptr_reg[ADDR_WIDTH-1:0] >> BANK_ROW_BITS) == bank)
                    words[wr_ptr_reg[BANK_ROW_BITS-1:0]] <= s_axis;
        end
`ifdef READ_ONEHOT
        reg [WIDTH-1:0] selected_word;
        integer select_row;
        always @* begin
            selected_word = 0;
            for (select_row=0; select_row<ROW_COUNT; select_row=select_row+1)
                selected_word = selected_word | (words[select_row] & {WIDTH{elastic_row_onehot_reg[select_row]}});
        end
`endif
        always @(posedge m_clk)
            if (m_axis_tready_pipe || ~m_axis_tvalid_pipe_reg)
`ifdef ELASTIC_READ
`ifdef READ_ONEHOT
                bank_read_data[bank] <= selected_word;
`else
                bank_read_data[bank] <= words[elastic_row_reg];
`endif
`else
`ifdef BANKED_READ_PREFETCH
                bank_read_data[bank] <= words[bank_read_row];
`else
                bank_read_data[bank] <= words[rd_ptr_reg[BANK_ROW_BITS-1:0]];
`endif
`endif
    end
`ifdef READ_BANK_ONEHOT
    integer output_group;
`endif
    always @* begin
        m_axis_pipe_reg[0] = bank_read_data[bank_select];
`ifdef READ_BANK_ONEHOT
        m_axis_pipe_reg[1] = 0;
        for (output_group=0; output_group<GROUP_COUNT; output_group=output_group+1)
            m_axis_pipe_reg[1] = m_axis_pipe_reg[1] | (group_read_data[output_group] & {WIDTH{group_select_onehot_reg[output_group]}});
`else
        m_axis_pipe_reg[1] = group_read_data[group_select];
`endif
    end
end endgenerate

// full when first TWO MSBs do NOT match, but rest matches
// (gray code equivalent of first MSB different but rest same)
wire full_raw = wr_ptr_gray_reg == (rd_ptr_gray_sync2_reg ^ {2'b11, {ADDR_WIDTH-1{1'b0}}});
wire full = USE_REGISTERED_FULL ? full_reg : full_raw;
// empty when pointers match exactly
wire empty = FRAME_FIFO ? (rd_ptr_reg == wr_ptr_commit_sync_reg) : (rd_ptr_gray_reg == wr_ptr_gray_sync2_reg);
// overflow within packet
wire full_wr_raw = wr_ptr_reg == (wr_ptr_commit_reg ^ {1'b1, {ADDR_WIDTH{1'b0}}});
wire full_wr = USE_REGISTERED_FULL ? full_wr_reg : full_wr_raw;

// control signals
reg write;
reg read;
reg store_output;

reg s_frame_reg = 1'b0;
reg m_frame_reg = 1'b0;

reg drop_frame_reg = 1'b0;
reg mark_frame_reg = 1'b0;
reg send_frame_reg = 1'b0;
reg overflow_reg = 1'b0;
reg bad_frame_reg = 1'b0;
reg good_frame_reg = 1'b0;

reg m_drop_frame_reg = 1'b0;
reg m_terminate_frame_reg = 1'b0;

reg [ADDR_WIDTH:0] s_depth_reg = 0;
reg [ADDR_WIDTH:0] s_depth_commit_reg = 0;
reg [ADDR_WIDTH:0] m_depth_reg = 0;
reg [ADDR_WIDTH:0] m_depth_commit_reg = 0;

reg overflow_sync1_reg = 1'b0;
reg overflow_sync2_reg = 1'b0;
reg overflow_sync3_reg = 1'b0;
reg overflow_sync4_reg = 1'b0;
reg bad_frame_sync1_reg = 1'b0;
reg bad_frame_sync2_reg = 1'b0;
reg bad_frame_sync3_reg = 1'b0;
reg bad_frame_sync4_reg = 1'b0;
reg good_frame_sync1_reg = 1'b0;
reg good_frame_sync2_reg = 1'b0;
reg good_frame_sync3_reg = 1'b0;
reg good_frame_sync4_reg = 1'b0;

assign s_axis_tready = (FRAME_FIFO ? (!full || (full_wr && DROP_OVERSIZE_FRAME) || DROP_WHEN_FULL) : (!full || MARK_WHEN_FULL)) && !s_rst_sync3_reg;

wire [WIDTH-1:0] s_axis;

generate
    assign s_axis[DATA_WIDTH-1:0] = s_axis_tdata;
    if (KEEP_ENABLE) assign s_axis[KEEP_OFFSET +: KEEP_WIDTH] = s_axis_tkeep;
    if (LAST_ENABLE) assign s_axis[LAST_OFFSET]               = s_axis_tlast | mark_frame_reg;
    if (ID_ENABLE)   assign s_axis[ID_OFFSET   +: ID_WIDTH]   = s_axis_tid;
    if (DEST_ENABLE) assign s_axis[DEST_OFFSET +: DEST_WIDTH] = s_axis_tdest;
    if (USER_ENABLE) assign s_axis[USER_OFFSET +: USER_WIDTH] = mark_frame_reg ? USER_BAD_FRAME_VALUE : s_axis_tuser;
endgenerate

wire [WIDTH-1:0] m_axis = m_axis_pipe_reg[RAM_PIPELINE+1-1];

wire                   m_axis_tready_pipe;
wire                   m_axis_tvalid_pipe = m_axis_tvalid_pipe_reg[RAM_PIPELINE+1-1];

wire [DATA_WIDTH-1:0]  m_axis_tdata_pipe  = m_axis[DATA_WIDTH-1:0];
wire [KEEP_WIDTH-1:0]  m_axis_tkeep_pipe  = KEEP_ENABLE ? m_axis[KEEP_OFFSET +: KEEP_WIDTH] : {KEEP_WIDTH{1'b1}};
wire                   m_axis_tlast_pipe  = LAST_ENABLE ? m_axis[LAST_OFFSET] | m_terminate_frame_reg : 1'b1;
wire [ID_WIDTH-1:0]    m_axis_tid_pipe    = ID_ENABLE   ? m_axis[ID_OFFSET +: ID_WIDTH] : {ID_WIDTH{1'b0}};
wire [DEST_WIDTH-1:0]  m_axis_tdest_pipe  = DEST_ENABLE ? m_axis[DEST_OFFSET +: DEST_WIDTH] : {DEST_WIDTH{1'b0}};
wire [USER_WIDTH-1:0]  m_axis_tuser_pipe  = USER_ENABLE ? (m_terminate_frame_reg ? USER_BAD_FRAME_VALUE : m_axis[USER_OFFSET +: USER_WIDTH]) : {USER_WIDTH{1'b0}};

wire                   m_axis_tready_out;
wire                   m_axis_tvalid_out;

wire [DATA_WIDTH-1:0]  m_axis_tdata_out;
wire [KEEP_WIDTH-1:0]  m_axis_tkeep_out;
wire                   m_axis_tlast_out;
wire [ID_WIDTH-1:0]    m_axis_tid_out;
wire [DEST_WIDTH-1:0]  m_axis_tdest_out;
wire [USER_WIDTH-1:0]  m_axis_tuser_out;

wire pipe_ready;

assign s_status_depth = (KEEP_ENABLE && KEEP_WIDTH > 1) ? {s_depth_reg, {$clog2(KEEP_WIDTH){1'b0}}} : s_depth_reg;
assign s_status_depth_commit = (KEEP_ENABLE && KEEP_WIDTH > 1) ? {s_depth_commit_reg, {$clog2(KEEP_WIDTH){1'b0}}} : s_depth_commit_reg;
assign s_status_overflow = overflow_reg;
assign s_status_bad_frame = bad_frame_reg;
assign s_status_good_frame = good_frame_reg;

assign m_status_depth = (KEEP_ENABLE && KEEP_WIDTH > 1) ? {m_depth_reg, {$clog2(KEEP_WIDTH){1'b0}}} : m_depth_reg;
assign m_status_depth_commit = (KEEP_ENABLE && KEEP_WIDTH > 1) ? {m_depth_commit_reg, {$clog2(KEEP_WIDTH){1'b0}}} : m_depth_commit_reg;
assign m_status_overflow = overflow_sync3_reg ^ overflow_sync4_reg;
assign m_status_bad_frame = bad_frame_sync3_reg ^ bad_frame_sync4_reg;
assign m_status_good_frame = good_frame_sync3_reg ^ good_frame_sync4_reg;

// reset synchronization
always @(posedge m_clk or posedge m_rst) begin
    if (m_rst) begin
        s_rst_sync1_reg <= 1'b1;
    end else begin
        s_rst_sync1_reg <= 1'b0;
    end
end

always @(posedge s_clk) begin
    s_rst_sync2_reg <= s_rst_sync1_reg;
    s_rst_sync3_reg <= s_rst_sync2_reg;
end

always @(posedge s_clk or posedge s_rst) begin
    if (s_rst) begin
        m_rst_sync1_reg <= 1'b1;
    end else begin
        m_rst_sync1_reg <= 1'b0;
    end
end

always @(posedge m_clk) begin
    m_rst_sync2_reg <= m_rst_sync1_reg;
    m_rst_sync3_reg <= m_rst_sync2_reg;
end

// Write logic
always @(posedge s_clk) begin
    wr_ptr_temp = wr_ptr_reg;
    if (USE_REGISTERED_FULL) begin
        full_reg <= full_raw;
`ifdef FORMAL
`ifdef FULL_LOOKAHEAD
        full_reference_reg <= full_raw;
`endif
`endif
        full_wr_reg <= full_wr_raw;
    end
    overflow_reg <= 1'b0;
    bad_frame_reg <= 1'b0;
    good_frame_reg <= 1'b0;

    if (FRAME_FIFO && wr_ptr_update_valid_reg) begin
        // have updated pointer to sync
        if (wr_ptr_update_reg == wr_ptr_update_ack_sync2_reg) begin
            // no sync in progress; sync update
            wr_ptr_update_valid_reg <= 1'b0;
            wr_ptr_sync_commit_reg <= wr_ptr_commit_reg;
            wr_ptr_update_reg <= !wr_ptr_update_ack_sync2_reg;
        end
    end

    if (s_axis_tready && s_axis_tvalid && LAST_ENABLE) begin
        // track input frame status
        s_frame_reg <= !s_axis_tlast;
    end

    if (s_rst_sync3_reg && LAST_ENABLE) begin
        // if sink side is reset during transfer, drop partial frame
        if (s_frame_reg && !(s_axis_tready && s_axis_tvalid && s_axis_tlast)) begin
            drop_frame_reg <= 1'b1;
        end
        if (s_axis_tready && s_axis_tvalid && !s_axis_tlast) begin
            drop_frame_reg <= 1'b1;
        end
    end

    if (FRAME_FIFO) begin
        // frame FIFO mode
        if (s_axis_tready && s_axis_tvalid) begin
            // transfer in
`ifdef FAST_CONTROL
            if (USE_REGISTERED_FULL) full_wr_reg <= full_wr_increment;
`ifdef FULL_LOOKAHEAD
            if (USE_REGISTERED_FULL) full_reg <= full_increment;
`endif
`endif
            if ((full && DROP_WHEN_FULL) || (full_wr && DROP_OVERSIZE_FRAME) || drop_frame_reg) begin
`ifdef FAST_CONTROL
                if (USE_REGISTERED_FULL) full_wr_reg <= full_wr_raw;
`ifdef FULL_LOOKAHEAD
                if (USE_REGISTERED_FULL) full_reg <= full_raw;
`endif
`endif
                // full, packet overflow, or currently dropping frame
                // drop frame
                drop_frame_reg <= 1'b1;
                if (s_axis_tlast) begin
                    // end of frame, reset write pointer
                    wr_ptr_temp = wr_ptr_commit_reg;
                    wr_ptr_reg <= wr_ptr_temp;
                    update_write_decode(wr_ptr_temp);
`ifdef FAST_CONTROL
                    if (USE_REGISTERED_FULL) full_wr_reg <= 0;
`ifdef FULL_LOOKAHEAD
                    if (USE_REGISTERED_FULL) full_reg <= full_commit;
`endif
`endif
                    wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);
                    drop_frame_reg <= 1'b0;
                    overflow_reg <= 1'b1;
                end
            end else begin
                if (!USE_BANKED) mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
                wr_ptr_temp = wr_increment;
                wr_ptr_reg <= wr_ptr_temp;
                update_write_decode(wr_ptr_temp);
                wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);
                if (s_axis_tlast || (!DROP_OVERSIZE_FRAME && (full_wr || send_frame_reg))) begin
                    // end of frame or send frame
                    send_frame_reg <= !s_axis_tlast;
                    if (s_axis_tlast && DROP_BAD_FRAME && USER_BAD_FRAME_MASK & ~(s_axis_tuser ^ USER_BAD_FRAME_VALUE)) begin
                        // bad packet, reset write pointer
                        wr_ptr_temp = wr_ptr_commit_reg;
                        wr_ptr_reg <= wr_ptr_temp;
                        update_write_decode(wr_ptr_temp);
                        wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);
                        bad_frame_reg <= 1'b1;
`ifdef FULL_LOOKAHEAD
                        if (USE_REGISTERED_FULL) full_reg <= full_commit;
`endif
`ifdef FAST_CONTROL
                        if (USE_REGISTERED_FULL) full_wr_reg <= 0;
`endif
                    end else begin
                        // good packet or packet overflow, update write pointer
                        wr_ptr_temp = wr_increment;
                        wr_ptr_reg <= wr_ptr_temp;
                        update_write_decode(wr_ptr_temp);
                        wr_ptr_commit_reg <= wr_ptr_temp;
                        if (USE_REGISTERED_FULL) full_wr_reg <= 0;
                        wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);

                        if (wr_ptr_update_reg == wr_ptr_update_ack_sync2_reg) begin
                            // no sync in progress; sync update
                            wr_ptr_update_valid_reg <= 1'b0;
                            wr_ptr_sync_commit_reg <= wr_ptr_temp;
                            wr_ptr_update_reg <= !wr_ptr_update_ack_sync2_reg;
                        end else begin
                            // sync in progress; flag it for later
                            wr_ptr_update_valid_reg <= 1'b1;
                        end

                        good_frame_reg <= s_axis_tlast;
                    end
                end
            end
        end else if (s_axis_tvalid && full_wr && FRAME_FIFO && !DROP_OVERSIZE_FRAME) begin
            // data valid with packet overflow
            // update write pointer
            send_frame_reg <= 1'b1;
            wr_ptr_temp = wr_ptr_reg;
            wr_ptr_reg <= wr_ptr_temp;
            update_write_decode(wr_ptr_temp);
            wr_ptr_commit_reg <= wr_ptr_temp;
            if (USE_REGISTERED_FULL) full_wr_reg <= 0;
            wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);

            if (wr_ptr_update_reg == wr_ptr_update_ack_sync2_reg) begin
                // no sync in progress; sync update
                wr_ptr_update_valid_reg <= 1'b0;
                wr_ptr_sync_commit_reg <= wr_ptr_temp;
                wr_ptr_update_reg <= !wr_ptr_update_ack_sync2_reg;
            end else begin
                // sync in progress; flag it for later
                wr_ptr_update_valid_reg <= 1'b1;
            end
        end
    end else begin
        // normal FIFO mode
        if (s_axis_tready && s_axis_tvalid) begin
            if (drop_frame_reg && LAST_ENABLE) begin
                // currently dropping frame
                if (s_axis_tlast) begin
                    // end of frame
                    if (!full && mark_frame_reg && MARK_WHEN_FULL) begin
                        // terminate marked frame
                        mark_frame_reg <= 1'b0;
                        if (!USE_BANKED) mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
                        wr_ptr_temp = wr_increment;
                        wr_ptr_reg <= wr_ptr_temp;
                        update_write_decode(wr_ptr_temp);
                        wr_ptr_commit_reg <= wr_ptr_temp;
                        if (USE_REGISTERED_FULL) full_wr_reg <= 0;
                        wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);
                    end
                    // end of frame, clear drop flag
                    drop_frame_reg <= 1'b0;
                    overflow_reg <= 1'b1;
                end
            end else if ((full || mark_frame_reg) && MARK_WHEN_FULL) begin
                // full or marking frame
                // drop frame; mark if this isn't the first cycle
                drop_frame_reg <= 1'b1;
                mark_frame_reg <= mark_frame_reg || s_frame_reg;
                if (s_axis_tlast) begin
                    drop_frame_reg <= 1'b0;
                    overflow_reg <= 1'b1;
                end
            end else begin
                // transfer in
                if (!USE_BANKED) mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
                wr_ptr_temp = wr_increment;
                wr_ptr_reg <= wr_ptr_temp;
                update_write_decode(wr_ptr_temp);
                wr_ptr_commit_reg <= wr_ptr_temp;
                if (USE_REGISTERED_FULL) full_wr_reg <= 0;
                wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);
            end
        end else if ((!full && !drop_frame_reg && mark_frame_reg) && MARK_WHEN_FULL) begin
            // terminate marked frame
            mark_frame_reg <= 1'b0;
            if (!USE_BANKED) mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
            wr_ptr_temp = wr_increment;
            wr_ptr_reg <= wr_ptr_temp;
            update_write_decode(wr_ptr_temp);
            wr_ptr_commit_reg <= wr_ptr_temp;
            if (USE_REGISTERED_FULL) full_wr_reg <= 0;
            wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);
        end
    end

    if (s_rst_sync3_reg) begin
`ifdef FULL_LOOKAHEAD
        if (USE_REGISTERED_FULL && FRAME_FIFO) full_reg <= full_zero;
`endif
        wr_ptr_temp = 0;
        wr_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        update_write_decode(0);
        wr_ptr_commit_reg <= {ADDR_WIDTH+1{1'b0}};
        if (USE_REGISTERED_FULL) full_wr_reg <= 0;
        wr_ptr_gray_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_sync_commit_reg <= {ADDR_WIDTH+1{1'b0}};

        wr_ptr_update_valid_reg <= 1'b0;
        wr_ptr_update_reg <= 1'b0;
    end

    if (s_rst) begin
        wr_ptr_temp = 0;
        wr_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        update_write_decode(0);
        wr_ptr_commit_reg <= {ADDR_WIDTH+1{1'b0}};
        if (USE_REGISTERED_FULL) begin full_wr_reg <= 0; full_reg <= 0; end
`ifdef FORMAL
`ifdef FULL_LOOKAHEAD
        if (USE_REGISTERED_FULL) full_reference_reg <= 0;
`endif
`endif
        wr_ptr_gray_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_sync_commit_reg <= {ADDR_WIDTH+1{1'b0}};

        wr_ptr_update_valid_reg <= 1'b0;
        wr_ptr_update_reg <= 1'b0;

        s_frame_reg <= 1'b0;

        drop_frame_reg <= 1'b0;
        mark_frame_reg <= 1'b0;
        send_frame_reg <= 1'b0;
        overflow_reg <= 1'b0;
        bad_frame_reg <= 1'b0;
        good_frame_reg <= 1'b0;
    end
end

// Write-side status
always @(posedge s_clk) begin
    rd_ptr_conv_reg <= gray2bin(rd_ptr_gray_sync2_reg);
    s_depth_reg <= wr_ptr_reg - rd_ptr_conv_reg;
    s_depth_commit_reg <= wr_ptr_commit_reg - rd_ptr_conv_reg;
end

// pointer synchronization
always @(posedge s_clk) begin
    rd_ptr_gray_sync1_reg <= rd_ptr_gray_reg;
    rd_ptr_gray_sync2_reg <= rd_ptr_gray_sync1_reg;
    wr_ptr_update_ack_sync1_reg <= wr_ptr_update_sync3_reg;
    wr_ptr_update_ack_sync2_reg <= wr_ptr_update_ack_sync1_reg;

    if (s_rst) begin
        rd_ptr_gray_sync1_reg <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_sync2_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_update_ack_sync1_reg <= 1'b0;
        wr_ptr_update_ack_sync2_reg <= 1'b0;
    end
end

always @(posedge m_clk) begin
    wr_ptr_gray_sync1_reg <= wr_ptr_gray_reg;
    wr_ptr_gray_sync2_reg <= wr_ptr_gray_sync1_reg;
    if (FRAME_FIFO && wr_ptr_update_sync2_reg ^ wr_ptr_update_sync3_reg) begin
        wr_ptr_commit_sync_reg <= wr_ptr_sync_commit_reg;
    end
    wr_ptr_update_sync1_reg <= wr_ptr_update_visible;
    wr_ptr_update_sync2_reg <= wr_ptr_update_sync1_reg;
    wr_ptr_update_sync3_reg <= wr_ptr_update_sync2_reg;

    if (FRAME_FIFO && m_rst_sync3_reg) begin
        wr_ptr_gray_sync1_reg <= {ADDR_WIDTH+1{1'b0}};
    end

    if (m_rst) begin
        wr_ptr_gray_sync1_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray_sync2_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_commit_sync_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_update_sync1_reg <= 1'b0;
        wr_ptr_update_sync2_reg <= 1'b0;
        wr_ptr_update_sync3_reg <= 1'b0;
    end
end

// status synchronization
always @(posedge s_clk) begin
    overflow_sync1_reg <= overflow_sync1_reg ^ overflow_reg;
    bad_frame_sync1_reg <= bad_frame_sync1_reg ^ bad_frame_reg;
    good_frame_sync1_reg <= good_frame_sync1_reg ^ good_frame_reg;

    if (s_rst) begin
        overflow_sync1_reg <= 1'b0;
        bad_frame_sync1_reg <= 1'b0;
        good_frame_sync1_reg <= 1'b0;
    end
end

always @(posedge m_clk) begin
    overflow_sync2_reg <= overflow_sync1_reg;
    overflow_sync3_reg <= overflow_sync2_reg;
    overflow_sync4_reg <= overflow_sync3_reg;
    bad_frame_sync2_reg <= bad_frame_sync1_reg;
    bad_frame_sync3_reg <= bad_frame_sync2_reg;
    bad_frame_sync4_reg <= bad_frame_sync3_reg;
    good_frame_sync2_reg <= good_frame_sync1_reg;
    good_frame_sync3_reg <= good_frame_sync2_reg;
    good_frame_sync4_reg <= good_frame_sync3_reg;

    if (m_rst) begin
        overflow_sync2_reg <= 1'b0;
        overflow_sync3_reg <= 1'b0;
        overflow_sync4_reg <= 1'b0;
        bad_frame_sync2_reg <= 1'b0;
        bad_frame_sync3_reg <= 1'b0;
        bad_frame_sync4_reg <= 1'b0;
        good_frame_sync2_reg <= 1'b0;
        good_frame_sync3_reg <= 1'b0;
        good_frame_sync4_reg <= 1'b0;
    end
end

// Read logic
integer j;

always @(posedge m_clk) begin
`ifdef ELASTIC_READ
`ifdef REGISTER_EMPTY
    // Compare both pointer outcomes in parallel, then select one flag bit.
    // Account for the commit synchronizer update on this same clock edge.
    elastic_empty_reg <= elastic_empty_hold;
    if (USE_BANKED && elastic_address_ready && !elastic_empty &&
            !m_rst_sync3_reg && !m_drop_frame_reg && pipe_ready)
        elastic_empty_reg <= elastic_empty_increment;
    if (m_rst_sync3_reg) elastic_empty_reg <= (elastic_visible_commit == 0);
    if (m_rst) elastic_empty_reg <= 1;
`endif
    // Return storage credit only after the RAM captures the pending word.
    if (USE_BANKED && elastic_data_ready && elastic_valid_reg) begin
        rd_ptr_temp = rd_ptr_reg + 1;
        rd_ptr_reg <= rd_ptr_temp;
        rd_ptr_gray_reg <= rd_ptr_temp ^ (rd_ptr_temp >> 1);
    end
    if (USE_BANKED && elastic_address_ready) begin
        elastic_valid_reg <= 0;
        if (!elastic_empty && !m_rst_sync3_reg && !m_drop_frame_reg && pipe_ready) begin
            elastic_row_reg <= elastic_fetch_ptr_reg[BANK_ROW_BITS-1:0];
`ifdef READ_ONEHOT
            elastic_row_onehot_reg <= {{ROW_COUNT-1{1'b0}},1'b1} << elastic_fetch_ptr_reg[BANK_ROW_BITS-1:0];
`endif
            elastic_bank_reg <= elastic_fetch_ptr_reg[ADDR_WIDTH-1:0] >> BANK_ROW_BITS;
            elastic_valid_reg <= 1;
`ifdef FAST_CONTROL
            elastic_fetch_ptr_reg <= elastic_fetch_increment;
            fetch_carry_reg <= &elastic_fetch_increment[FETCH_SPLIT-1:0];
`else
            elastic_fetch_ptr_reg <= elastic_fetch_ptr_reg + 1;
`endif
        end
    end
    if (m_rst || m_rst_sync3_reg) begin
        elastic_valid_reg <= 0;
        elastic_fetch_ptr_reg <= 0;
`ifdef FAST_CONTROL
        fetch_carry_reg <= 0;
`endif
    end
`endif
    if (m_axis_tready_pipe) begin
        // output ready; invalidate stage
        m_axis_tvalid_pipe_reg[RAM_PIPELINE+1-1] <= 1'b0;
        m_terminate_frame_reg <= 1'b0;
    end

    for (j = RAM_PIPELINE+1-1; j > 0; j = j - 1) begin
        if (m_axis_tready_pipe || ((~m_axis_tvalid_pipe_reg) >> j)) begin
            // output ready or bubble in pipeline; transfer down pipeline
            m_axis_tvalid_pipe_reg[j] <= m_axis_tvalid_pipe_reg[j-1];
            if (USE_BANKED && j == 1) begin
                for (group_index=0; group_index<GROUP_COUNT; group_index=group_index+1)
`ifdef READ_BANK_ONEHOT
                    group_read_data[group_index] <= selected_bank_group[group_index];
                group_select_onehot_reg <= {{GROUP_COUNT-1{1'b0}},1'b1} << (bank_select >> MID_BITS);
`else
                    group_read_data[group_index] <= bank_read_data[(group_index << MID_BITS) + (bank_select & ((1 << MID_BITS)-1))];
`endif
                group_select <= bank_select >> MID_BITS;
            end
            else begin
                m_axis_pipe_reg[j] <= m_axis_pipe_reg[j-1];
            end
            m_axis_tvalid_pipe_reg[j-1] <= 1'b0;
        end
    end

    if (m_axis_tready_pipe || ~m_axis_tvalid_pipe_reg) begin
        // output ready or bubble in pipeline; read new data from FIFO
        m_axis_tvalid_pipe_reg[0] <= 1'b0;
        if (USE_BANKED) begin
`ifdef ELASTIC_READ
            bank_select <= elastic_bank_reg;
`ifdef READ_BANK_ONEHOT
            bank_select_onehot_reg <= {{(1 << MID_BITS)-1{1'b0}},1'b1} << (elastic_bank_reg & ((1 << MID_BITS)-1));
`endif
            m_axis_tvalid_pipe_reg[0] <= elastic_valid_reg;
`else
`ifdef BANKED_READ_PREFETCH
            // Data captured on this edge belongs to the previously issued
            // prefetch address.  Present that address while issuing the
            // current pointer for the next edge.
            bank_select <= bank_read_bank;
`ifdef READ_BANK_ONEHOT
            bank_select_onehot_reg <= {{(1 << MID_BITS)-1{1'b0}},1'b1} << (bank_read_bank & ((1 << MID_BITS)-1));
`endif
            m_axis_tvalid_pipe_reg[0] <= bank_read_valid;
            bank_read_valid <= 1'b0;
            if (!empty && !m_rst_sync3_reg && !m_drop_frame_reg && pipe_ready) begin
                bank_read_row <= rd_ptr_reg[BANK_ROW_BITS-1:0];
                bank_read_bank <= rd_ptr_reg[ADDR_WIDTH-1:0] >> BANK_ROW_BITS;
                bank_read_valid <= 1'b1;
                rd_ptr_temp = rd_ptr_reg + 1;
                rd_ptr_reg <= rd_ptr_temp;
                rd_ptr_gray_reg <= rd_ptr_temp ^ (rd_ptr_temp >> 1);
            end
`else
            bank_select <= rd_ptr_reg[ADDR_WIDTH-1:0] >> BANK_ROW_BITS;
`ifdef READ_BANK_ONEHOT
            bank_select_onehot_reg <= {{(1 << MID_BITS)-1{1'b0}},1'b1} << ((rd_ptr_reg[ADDR_WIDTH-1:0] >> BANK_ROW_BITS) & ((1 << MID_BITS)-1));
`endif
            if (!empty && !m_rst_sync3_reg && !m_drop_frame_reg && pipe_ready) begin
                m_axis_tvalid_pipe_reg[0] <= 1'b1;
                rd_ptr_temp = rd_ptr_reg + 1;
                rd_ptr_reg <= rd_ptr_temp;
                rd_ptr_gray_reg <= rd_ptr_temp ^ (rd_ptr_temp >> 1);
            end
`endif
`endif
        end else begin
            m_axis_pipe_reg[0] <= mem[rd_ptr_reg[ADDR_WIDTH-1:0]];
            if (!empty && !m_rst_sync3_reg && !m_drop_frame_reg && pipe_ready) begin
                // not empty, increment pointer
                m_axis_tvalid_pipe_reg[0] <= 1'b1;
                rd_ptr_temp = rd_ptr_reg + 1;
                rd_ptr_reg <= rd_ptr_temp;
                rd_ptr_gray_reg <= rd_ptr_temp ^ (rd_ptr_temp >> 1);
            end
        end
    end

    if (m_axis_tvalid_pipe && LAST_ENABLE) begin
        // track output frame status
        if (m_axis_tlast_pipe && m_axis_tready_pipe) begin
            m_frame_reg <= 1'b0;
        end else begin
            m_frame_reg <= 1'b1;
        end
    end

    if (m_drop_frame_reg && (USE_OUTPUT_FIFO ? pipe_ready : m_axis_tready_pipe || !m_axis_tvalid_pipe) && LAST_ENABLE) begin
        // terminate frame
        // (only for frame transfers interrupted by source reset)
        m_axis_tvalid_pipe_reg[RAM_PIPELINE+1-1] <= 1'b1;
        m_terminate_frame_reg <= 1'b1;
        m_drop_frame_reg <= 1'b0;
    end

    if (m_rst_sync3_reg && LAST_ENABLE) begin
        // if source side is reset during transfer, drop partial frame

        // empty output pipeline, except for last stage
        if (RAM_PIPELINE > 0) begin
            m_axis_tvalid_pipe_reg[RAM_PIPELINE+1-2:0] <= 0;
        end

        if (m_frame_reg && (!m_axis_tvalid_pipe || (m_axis_tvalid_pipe && !m_axis_tlast_pipe)) &&
                !(m_drop_frame_reg || m_terminate_frame_reg)) begin
            // terminate frame
            m_drop_frame_reg <= 1'b1;
        end
    end

    if (m_rst_sync3_reg) begin
        rd_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_reg <= {ADDR_WIDTH+1{1'b0}};
`ifdef BANKED_READ_PREFETCH
        bank_read_row <= {BANK_ROW_BITS{1'b0}};
        bank_read_bank <= {BANK_SEL_WIDTH{1'b0}};
        bank_read_valid <= 1'b0;
`endif
    end

    if (m_rst) begin
        rd_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_reg <= {ADDR_WIDTH+1{1'b0}};
        m_axis_tvalid_pipe_reg <= 0;
        m_frame_reg <= 1'b0;
        m_drop_frame_reg <= 1'b0;
        m_terminate_frame_reg <= 1'b0;
`ifdef BANKED_READ_PREFETCH
        bank_read_row <= {BANK_ROW_BITS{1'b0}};
        bank_read_bank <= {BANK_SEL_WIDTH{1'b0}};
        bank_read_valid <= 1'b0;
`endif
    end
end

// Read-side status
always @(posedge m_clk) begin
    wr_ptr_conv_reg <= gray2bin(wr_ptr_gray_sync2_reg);
    m_depth_reg <= wr_ptr_conv_reg - rd_ptr_reg;
    m_depth_commit_reg <= FRAME_FIFO ? wr_ptr_commit_sync_reg - rd_ptr_reg : wr_ptr_conv_reg - rd_ptr_reg;
end

generate

if (!USE_OUTPUT_FIFO) begin

    assign pipe_ready = 1'b1;

    assign m_axis_tready_pipe = m_axis_tready_out;
    assign m_axis_tvalid_out = m_axis_tvalid_pipe;

    assign m_axis_tdata_out = m_axis_tdata_pipe;
    assign m_axis_tkeep_out = m_axis_tkeep_pipe;
    assign m_axis_tlast_out = m_axis_tlast_pipe;
    assign m_axis_tid_out   = m_axis_tid_pipe;
    assign m_axis_tdest_out = m_axis_tdest_pipe;
    assign m_axis_tuser_out = m_axis_tuser_pipe;

end else begin : output_fifo

    // output datapath logic
    reg [DATA_WIDTH-1:0] m_axis_tdata_reg  = {DATA_WIDTH{1'b0}};
    reg [KEEP_WIDTH-1:0] m_axis_tkeep_reg  = {KEEP_WIDTH{1'b0}};
    reg                  m_axis_tvalid_reg = 1'b0;
    reg                  m_axis_tlast_reg  = 1'b0;
    reg [ID_WIDTH-1:0]   m_axis_tid_reg    = {ID_WIDTH{1'b0}};
    reg [DEST_WIDTH-1:0] m_axis_tdest_reg  = {DEST_WIDTH{1'b0}};
    reg [USER_WIDTH-1:0] m_axis_tuser_reg  = {USER_WIDTH{1'b0}};

    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
    reg out_fifo_half_full_reg = 1'b0;

    wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
    wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [DATA_WIDTH-1:0] out_fifo_tdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [KEEP_WIDTH-1:0] out_fifo_tkeep[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg                  out_fifo_tlast[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [ID_WIDTH-1:0]   out_fifo_tid[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [DEST_WIDTH-1:0] out_fifo_tdest[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [USER_WIDTH-1:0] out_fifo_tuser[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

    assign pipe_ready = !out_fifo_half_full_reg;

    assign m_axis_tready_pipe = 1'b1;

    assign m_axis_tdata_out  = m_axis_tdata_reg;
    assign m_axis_tkeep_out  = KEEP_ENABLE ? m_axis_tkeep_reg : {KEEP_WIDTH{1'b1}};
    assign m_axis_tvalid_out = m_axis_tvalid_reg;
    assign m_axis_tlast_out  = LAST_ENABLE ? m_axis_tlast_reg : 1'b1;
    assign m_axis_tid_out    = ID_ENABLE   ? m_axis_tid_reg   : {ID_WIDTH{1'b0}};
    assign m_axis_tdest_out  = DEST_ENABLE ? m_axis_tdest_reg : {DEST_WIDTH{1'b0}};
    assign m_axis_tuser_out  = USER_ENABLE ? m_axis_tuser_reg : {USER_WIDTH{1'b0}};

    always @(posedge m_clk) begin
        m_axis_tvalid_reg <= m_axis_tvalid_reg && !m_axis_tready_out;

        out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

        if (!out_fifo_full && m_axis_tvalid_pipe) begin
            out_fifo_tdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tdata_pipe;
            out_fifo_tkeep[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tkeep_pipe;
            out_fifo_tlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tlast_pipe;
            out_fifo_tid[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tid_pipe;
            out_fifo_tdest[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tdest_pipe;
            out_fifo_tuser[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tuser_pipe;
            out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
        end

        if (!out_fifo_empty && (!m_axis_tvalid_reg || m_axis_tready_out)) begin
            m_axis_tdata_reg <= out_fifo_tdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tkeep_reg <= out_fifo_tkeep[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tvalid_reg <= 1'b1;
            m_axis_tlast_reg <= out_fifo_tlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tid_reg <= out_fifo_tid[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tdest_reg <= out_fifo_tdest[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tuser_reg <= out_fifo_tuser[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
        end

        if (m_rst) begin
            out_fifo_wr_ptr_reg <= 0;
            out_fifo_rd_ptr_reg <= 0;
            m_axis_tvalid_reg <= 1'b0;
        end
    end

end

if (PAUSE_ENABLE) begin : pause

    // Pause logic
    reg pause_reg = 1'b0;
    reg pause_frame_reg = 1'b0;

    reg s_pause_req_sync1_reg;
    reg s_pause_req_sync2_reg;
    reg s_pause_req_sync3_reg;
    reg s_pause_ack_sync1_reg;
    reg s_pause_ack_sync2_reg;
    reg s_pause_ack_sync3_reg;

    always @(posedge s_clk) begin
        s_pause_req_sync1_reg <= s_pause_req;
        s_pause_ack_sync2_reg <= s_pause_ack_sync1_reg;
        s_pause_ack_sync3_reg <= s_pause_ack_sync2_reg;
    end

    always @(posedge m_clk) begin
        s_pause_req_sync2_reg <= s_pause_req_sync1_reg;
        s_pause_req_sync3_reg <= s_pause_req_sync2_reg;
        s_pause_ack_sync1_reg <= pause_reg;
    end

    assign m_axis_tready_out = m_axis_tready && !pause_reg;
    assign m_axis_tvalid = m_axis_tvalid_out && !pause_reg;

    assign m_axis_tdata = m_axis_tdata_out;
    assign m_axis_tkeep = m_axis_tkeep_out;
    assign m_axis_tlast = m_axis_tlast_out;
    assign m_axis_tid   = m_axis_tid_out;
    assign m_axis_tdest = m_axis_tdest_out;
    assign m_axis_tuser = m_axis_tuser_out;

    assign s_pause_ack = s_pause_ack_sync3_reg;
    assign m_pause_ack = pause_reg;

    always @(posedge m_clk) begin
        if (FRAME_PAUSE) begin
            if (pause_reg) begin
                // paused; update pause status
                pause_reg <= m_pause_req || s_pause_req_sync3_reg;
            end else if (m_axis_tvalid_out) begin
                // frame transfer; set frame bit
                pause_frame_reg <= 1'b1;
                if (m_axis_tready && m_axis_tlast) begin
                    // end of frame; clear frame bit and update pause status
                    pause_frame_reg <= 1'b0;
                    pause_reg <= m_pause_req || s_pause_req_sync3_reg;
                end
            end else if (!pause_frame_reg) begin
                // idle; update pause status
                pause_reg <= m_pause_req || s_pause_req_sync3_reg;
            end
        end else begin
            pause_reg <= m_pause_req || s_pause_req_sync3_reg;
        end

        if (m_rst) begin
            pause_frame_reg <= 1'b0;
            pause_reg <= 1'b0;
        end
    end

end else begin

    assign m_axis_tready_out = m_axis_tready;
    assign m_axis_tvalid = m_axis_tvalid_out;

    assign m_axis_tdata = m_axis_tdata_out;
    assign m_axis_tkeep = m_axis_tkeep_out;
    assign m_axis_tlast = m_axis_tlast_out;
    assign m_axis_tid   = m_axis_tid_out;
    assign m_axis_tdest = m_axis_tdest_out;
    assign m_axis_tuser = m_axis_tuser_out;

    assign s_pause_ack = 1'b0;
    assign m_pause_ack = 1'b0;

end

endgenerate

endmodule

`resetall
