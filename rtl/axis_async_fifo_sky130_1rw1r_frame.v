/*
 * Frame-level asynchronous FIFO backed by Sky130 OpenRAM 1RW1R macros.
 *
 * This is deliberately a frame FIFO: one slot is filled in the source clock
 * domain while the other slot is drained in the destination clock domain.
 * Each 4096-byte slot uses two 2 kB 32-bit 1RW1R macros.  The source writes
 * through port 0 and the destination reads through independent port 1 clocks;
 * no RTL clock mux is used on the memory data path.
 *
 * The MAC uses DATA_WIDTH=8 and FRAME_FIFO=1.  Other configurations should
 * continue to use axis_async_fifo_banked.v until they are explicitly adapted.
 */
`resetall
`timescale 1ns / 1ps
`default_nettype none

module axis_async_fifo #
(
    parameter DEPTH = 4096,
    parameter DATA_WIDTH = 8,
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    parameter KEEP_WIDTH = ((DATA_WIDTH+7)/8),
    parameter LAST_ENABLE = 1,
    parameter ID_ENABLE = 0,
    parameter ID_WIDTH = 8,
    parameter DEST_ENABLE = 0,
    parameter DEST_WIDTH = 8,
    parameter USER_ENABLE = 1,
    parameter USER_WIDTH = 1,
    parameter RAM_PIPELINE = 1,
    parameter OUTPUT_FIFO_ENABLE = 0,
    parameter FRAME_FIFO = 0,
    parameter USER_BAD_FRAME_VALUE = 1'b1,
    parameter USER_BAD_FRAME_MASK = 1'b1,
    parameter DROP_OVERSIZE_FRAME = FRAME_FIFO,
    parameter DROP_BAD_FRAME = 0,
    parameter DROP_WHEN_FULL = 0,
    parameter MARK_WHEN_FULL = 0,
    parameter PAUSE_ENABLE = 0,
    parameter FRAME_PAUSE = FRAME_FIFO
)
(
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
    input  wire                   s_pause_req,
    output wire                   s_pause_ack,
    input  wire                   m_pause_req,
    output wire                   m_pause_ack,
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

// Preserve the original FIFO capacity per direction.  Ping-pong buffering
// uses two slots, so the physical storage is 2*DEPTH bytes per FIFO.
localparam SLOT_DEPTH = DEPTH;
localparam SLOT_ADDR_WIDTH = $clog2(SLOT_DEPTH);
localparam [SLOT_ADDR_WIDTH-1:0] LAST_SLOT_ADDR = {SLOT_ADDR_WIDTH{1'b1}};
localparam MACRO_ADDR_WIDTH = 9;
localparam MACRO_WORD_BYTES = 4;
localparam MACRO_SELECT_BIT = 11;

`ifndef SYNTHESIS
initial begin
    if (DATA_WIDTH != 8 || !FRAME_FIFO || DEPTH != 4096)
        $error("Sky130 SRAM mode requires DATA_WIDTH=8, FRAME_FIFO=1, DEPTH=4096");
end
`endif

function [1:0] bin2gray2(input [1:0] b);
    bin2gray2 = b ^ (b >> 1);
endfunction

function [1:0] gray2bin2(input [1:0] g);
    gray2bin2[1] = g[1];
    gray2bin2[0] = g[1] ^ g[0];
endfunction

reg [1:0] wr_count_bin = 0;
reg [1:0] wr_count_gray = 0;
reg [1:0] rd_count_bin = 0;
reg [1:0] rd_count_gray = 0;

(* SHREG_EXTRACT = "NO" *) reg [1:0] rd_release_gray_sync1 = 0;
(* SHREG_EXTRACT = "NO" *) reg [1:0] rd_release_gray_sync2 = 0;
(* SHREG_EXTRACT = "NO" *) reg [1:0] wr_count_gray_sync1 = 0;
(* SHREG_EXTRACT = "NO" *) reg [1:0] wr_count_gray_sync2 = 0;

wire [1:0] rd_release_bin_sync = gray2bin2(rd_release_gray_sync2);
wire [1:0] wr_count_bin_sync = gray2bin2(wr_count_gray_sync2);
wire [1:0] source_occupancy = wr_count_bin - rd_release_bin_sync;
wire source_full = source_occupancy == 2;
wire destination_empty = rd_count_bin == wr_count_bin_sync;
// Registered frame credits keep the AXI ready path out of the Gray-pointer
// comparator.  The FIFO has two ping-pong slots, so this counter is bounded
// to 0..2 and is updated on frame commit/release events.
reg [1:0] source_frame_count = 0;
reg [1:0] source_release_seen = 0;
wire source_frame_full = source_frame_count == 2;

reg wr_active = 1'b0;
reg wr_drop = 1'b0;
reg wr_bad = 1'b0;
reg [SLOT_ADDR_WIDTH-1:0] wr_addr = 0;
reg status_overflow_reg = 1'b0;
reg status_bad_reg = 1'b0;
reg status_good_reg = 1'b0;

reg rd_active = 1'b0;
reg rd_out_valid = 1'b0;
reg [SLOT_ADDR_WIDTH-1:0] rd_addr = 0;
reg [SLOT_ADDR_WIDTH:0] rd_frame_len = 0;
reg rd_frame_user = 1'b0;
reg [31:0] rd_word_data = 0;
reg [7:0] rd_data_reg = 0;
reg rd_load_pending_q = 1'b0;
reg rd_present_q = 1'b0;
reg rd_req_valid_q = 1'b0;
reg rd_req_slot_q = 1'b0;
reg rd_req_macro_q = 1'b0;
reg rd_req_prefetch_q = 1'b0;
reg [MACRO_ADDR_WIDTH-1:0] rd_req_addr_q = 0;
reg rd_resp_valid_q = 1'b0;
reg rd_resp_slot_q = 1'b0;
reg rd_resp_macro_q = 1'b0;
reg rd_resp_prefetch_q = 1'b0;
reg [31:0] rd_prefetch_data = 0;
reg rd_prefetch_valid_q = 1'b0;

reg [SLOT_ADDR_WIDTH:0] frame_len_mem [0:1];
reg frame_user_mem [0:1];

wire source_user_bad = USER_ENABLE && ((s_axis_tuser & USER_BAD_FRAME_MASK) == USER_BAD_FRAME_VALUE);
wire source_slot = wr_count_bin[0];
wire destination_slot = rd_count_bin[0];
assign s_axis_tready = !s_rst && !source_frame_full;
wire source_fire = s_axis_tvalid && s_axis_tready;
wire source_frame_commit = source_fire && s_axis_tlast && !wr_drop &&
    !(DROP_BAD_FRAME && (wr_bad || source_user_bad));
wire source_frame_release = rd_release_bin_sync != source_release_seen;
assign m_axis_tvalid = rd_out_valid;
assign m_axis_tdata = rd_data_reg;
assign m_axis_tkeep = {KEEP_WIDTH{1'b1}};
assign m_axis_tlast = rd_out_valid && ({1'b0, rd_addr} == rd_last_addr);
assign m_axis_tid = {ID_WIDTH{1'b0}};
assign m_axis_tdest = {DEST_WIDTH{1'b0}};
assign m_axis_tuser = USER_ENABLE ? {{(USER_WIDTH-1){1'b0}}, rd_frame_user} : {USER_WIDTH{1'b0}};
assign s_pause_ack = 1'b0;
assign m_pause_ack = 1'b0;
assign s_status_overflow = status_overflow_reg;
assign s_status_bad_frame = status_bad_reg;
assign s_status_good_frame = status_good_reg;
assign m_status_overflow = 1'b0;
assign m_status_bad_frame = 1'b0;
assign m_status_good_frame = 1'b0;
assign s_status_depth = {{($clog2(DEPTH)-1){1'b0}}, source_occupancy};
assign s_status_depth_commit = s_status_depth;
assign m_status_depth = {{($clog2(DEPTH)-1){1'b0}}, (wr_count_bin_sync - rd_count_bin)};
assign m_status_depth_commit = m_status_depth;

wire wr_macro = wr_addr[MACRO_SELECT_BIT];
wire [MACRO_ADDR_WIDTH-1:0] wr_word_addr = wr_addr[10:2];
wire [3:0] wr_wmask = 4'b0001 << wr_addr[1:0];
wire [31:0] wr_din = {4{s_axis_tdata}};
wire [31:0] slot0_rd_q [0:1];
wire [31:0] slot1_rd_q [0:1];
wire [31:0] slot0_wr_q [0:1];
wire [31:0] slot1_wr_q [0:1];
wire [31:0] rd_q_selected = rd_resp_slot_q ? slot1_rd_q[rd_resp_macro_q] : slot0_rd_q[rd_resp_macro_q];
wire rd_req_slot_macro = rd_req_slot_q;
wire [SLOT_ADDR_WIDTH-1:0] rd_next_addr = rd_addr + 1'b1;
wire [SLOT_ADDR_WIDTH-1:0] rd_prefetch_addr = rd_next_addr + 4;
wire [SLOT_ADDR_WIDTH:0] rd_last_addr = rd_frame_len - 1'b1;

genvar macro_index;
generate
    for (macro_index = 0; macro_index < 2; macro_index = macro_index + 1) begin : sky130_slot0_macro
        sky130_sram_2kbyte_1rw1r_32x512_8_wrapper mem0 (
            .wr_clk   (s_clk),
            .wr_en    (source_fire && !wr_drop && !source_slot && (wr_macro == macro_index)),
            .wr_we    (source_fire && !wr_drop && !source_slot && (wr_macro == macro_index)),
            .wr_wmask (wr_wmask),
            .wr_addr  (wr_word_addr),
            .wr_din   (wr_din),
            .wr_dout  (slot0_wr_q[macro_index]),
            .rd_clk   (m_clk),
            .rd_en    (rd_req_valid_q && !rd_req_slot_macro && (rd_req_macro_q == macro_index)),
            .rd_addr  (rd_req_addr_q),
            .rd_dout  (slot0_rd_q[macro_index])
        );
    end
    for (macro_index = 0; macro_index < 2; macro_index = macro_index + 1) begin : sky130_slot1_macro
        sky130_sram_2kbyte_1rw1r_32x512_8_wrapper mem1 (
            .wr_clk   (s_clk),
            .wr_en    (source_fire && !wr_drop && source_slot && (wr_macro == macro_index)),
            .wr_we    (source_fire && !wr_drop && source_slot && (wr_macro == macro_index)),
            .wr_wmask (wr_wmask),
            .wr_addr  (wr_word_addr),
            .wr_din   (wr_din),
            .wr_dout  (slot1_wr_q[macro_index]),
            .rd_clk   (m_clk),
            .rd_en    (rd_req_valid_q && rd_req_slot_macro && (rd_req_macro_q == macro_index)),
            .rd_addr  (rd_req_addr_q),
            .rd_dout  (slot1_rd_q[macro_index])
        );
    end
endgenerate

always @(posedge s_clk) begin
    if (s_rst) begin
        source_frame_count <= 0;
        source_release_seen <= 0;
        rd_release_gray_sync1 <= 0;
        rd_release_gray_sync2 <= 0;
        wr_count_bin <= 0;
        wr_count_gray <= 0;
        wr_active <= 0;
        wr_drop <= 0;
        wr_bad <= 0;
        wr_addr <= 0;
        status_overflow_reg <= 0;
        status_bad_reg <= 0;
        status_good_reg <= 0;
    end else begin
        source_release_seen <= rd_release_bin_sync;
        case ({source_frame_commit, source_frame_release})
            2'b10: if (source_frame_count != 2) source_frame_count <= source_frame_count + 1'b1;
            2'b01: if (source_frame_count != 0) source_frame_count <= source_frame_count - 1'b1;
            default: source_frame_count <= source_frame_count;
        endcase
        rd_release_gray_sync1 <= rd_count_gray;
        rd_release_gray_sync2 <= rd_release_gray_sync1;
        status_overflow_reg <= 0;
        status_bad_reg <= 0;
        status_good_reg <= 0;

        if (source_full && s_axis_tvalid)
            status_overflow_reg <= 1'b1;

        if (source_fire) begin
            if (!wr_active) begin
                wr_active <= 1'b1;
                wr_addr <= 1;
                wr_bad <= source_user_bad;
                if (s_axis_tlast) begin
                    wr_active <= 1'b0;
                    if (DROP_BAD_FRAME && source_user_bad) begin
                        status_bad_reg <= 1'b1;
                    end else begin
                        frame_len_mem[source_slot] <= {{SLOT_ADDR_WIDTH{1'b0}}, 1'b1};
                        frame_user_mem[source_slot] <= source_user_bad;
                        wr_count_bin <= wr_count_bin + 1'b1;
                        wr_count_gray <= bin2gray2(wr_count_bin + 1'b1);
                        status_good_reg <= 1'b1;
                    end
                    wr_addr <= 0;
                    wr_bad <= 0;
                end
            end else begin
                if (wr_addr == LAST_SLOT_ADDR && !s_axis_tlast) begin
                    wr_drop <= 1'b1;
                    status_overflow_reg <= 1'b1;
                end
                if (wr_addr != LAST_SLOT_ADDR)
                    wr_addr <= wr_addr + 1'b1;
                if (s_axis_tlast) begin
                    wr_active <= 1'b0;
                    if (wr_drop || (DROP_BAD_FRAME && (wr_bad || source_user_bad))) begin
                        status_bad_reg <= 1'b1;
                    end else begin
                        frame_len_mem[source_slot] <= {1'b0, wr_addr} + 1'b1;
                        frame_user_mem[source_slot] <= wr_bad || source_user_bad;
                        wr_count_bin <= wr_count_bin + 1'b1;
                        wr_count_gray <= bin2gray2(wr_count_bin + 1'b1);
                        status_good_reg <= 1'b1;
                    end
                    wr_drop <= 1'b0;
                    wr_bad <= 1'b0;
                    wr_addr <= 0;
                end else begin
                    wr_bad <= wr_bad || source_user_bad;
                end
            end
        end
    end
end

always @(posedge m_clk) begin
    if (m_rst) begin
        wr_count_gray_sync1 <= 0;
        wr_count_gray_sync2 <= 0;
        rd_count_bin <= 0;
        rd_count_gray <= 0;
        rd_active <= 0;
        rd_out_valid <= 0;
        rd_addr <= 0;
        rd_frame_len <= 0;
        rd_frame_user <= 0;
        rd_word_data <= 0;
        rd_data_reg <= 0;
        rd_load_pending_q <= 1'b0;
        rd_present_q <= 1'b0;
        rd_req_valid_q <= 0;
        rd_req_slot_q <= 0;
        rd_req_macro_q <= 0;
        rd_req_prefetch_q <= 0;
        rd_req_addr_q <= 0;
        rd_resp_valid_q <= 0;
        rd_resp_slot_q <= 0;
        rd_resp_macro_q <= 0;
        rd_resp_prefetch_q <= 0;
        rd_prefetch_data <= 0;
        rd_prefetch_valid_q <= 1'b0;
    end else begin
        wr_count_gray_sync1 <= wr_count_gray;
        wr_count_gray_sync2 <= wr_count_gray_sync1;

        // The macro request is launched on this edge and is captured by the
        // synchronous 1R port on the following edge.  Delay the response
        // marker by one cycle so the registered macro Q is aligned with its
        // address and slot metadata.
        rd_resp_valid_q <= rd_req_valid_q;
        rd_resp_slot_q <= rd_req_slot_q;
        rd_resp_macro_q <= rd_req_macro_q;
        rd_resp_prefetch_q <= rd_req_prefetch_q;
        rd_req_valid_q <= 1'b0;

        if (rd_resp_valid_q && rd_resp_prefetch_q) begin
            rd_prefetch_data <= rd_q_selected;
            rd_prefetch_valid_q <= 1'b1;
        end

        if (!rd_active) begin
            rd_out_valid <= 0;
            if (!destination_empty) begin
                rd_active <= 1'b1;
                rd_addr <= 0;
                rd_frame_len <= frame_len_mem[destination_slot];
                rd_frame_user <= frame_user_mem[destination_slot];
                rd_req_valid_q <= 1'b1;
                rd_req_slot_q <= destination_slot;
                rd_req_macro_q <= 1'b0;
                rd_req_prefetch_q <= 1'b0;
                rd_req_addr_q <= 0;
            end
        end else if (rd_resp_valid_q && !rd_resp_prefetch_q) begin
            // A word contains four sequential AXI bytes.  The read macro is
            // accessed only at word boundaries, so the output path has one
            // full cycle per byte with no clock-domain mux on the SRAM port.
            rd_word_data <= rd_q_selected;
            rd_load_pending_q <= 1'b1;
            if (rd_frame_len > 4) begin
                rd_req_valid_q <= 1'b1;
                rd_req_slot_q <= destination_slot;
                rd_req_macro_q <= 1'b0;
                rd_req_prefetch_q <= 1'b1;
                rd_req_addr_q <= 1;
            end
        end else if (rd_load_pending_q) begin
            // Keep the response and AXI-valid transitions on separate clock
            // edges so the behavioral and hard macros align at word starts.
            rd_data_reg <= rd_word_data[7:0];
            rd_load_pending_q <= 1'b0;
            rd_present_q <= 1'b1;
        end else if (rd_present_q) begin
            rd_present_q <= 1'b0;
            rd_out_valid <= 1'b1;
        end else if (rd_out_valid && m_axis_tready) begin
            if ({1'b0, rd_addr} == rd_last_addr) begin
                rd_out_valid <= 1'b0;
                rd_active <= 1'b0;
                rd_count_bin <= rd_count_bin + 1'b1;
                rd_count_gray <= bin2gray2(rd_count_bin + 1'b1);
                rd_addr <= 0;
            end else if (rd_addr[1:0] == 2'b11) begin
                rd_addr <= rd_next_addr;
                if (rd_prefetch_valid_q) begin
                    rd_word_data <= rd_prefetch_data;
                    rd_data_reg <= rd_prefetch_data[7:0];
                    rd_prefetch_valid_q <= 1'b0;
                    rd_out_valid <= 1'b1;
                    if ({1'b0, rd_prefetch_addr} < rd_frame_len) begin
                        rd_req_valid_q <= 1'b1;
                        rd_req_slot_q <= destination_slot;
                        rd_req_macro_q <= rd_prefetch_addr[MACRO_SELECT_BIT];
                        rd_req_prefetch_q <= 1'b1;
                        rd_req_addr_q <= rd_prefetch_addr[10:2];
                    end
                end else begin
                    rd_out_valid <= 1'b0;
                    rd_req_valid_q <= 1'b1;
                    rd_req_slot_q <= destination_slot;
                    rd_req_macro_q <= rd_next_addr[MACRO_SELECT_BIT];
                    rd_req_prefetch_q <= 1'b0;
                    rd_req_addr_q <= rd_next_addr[10:2];
                end
            end else begin
                rd_addr <= rd_next_addr;
                case (rd_addr[1:0])
                    2'b00: rd_data_reg <= rd_word_data[15:8];
                    2'b01: rd_data_reg <= rd_word_data[23:16];
                    2'b10: rd_data_reg <= rd_word_data[31:24];
                    default: rd_data_reg <= rd_word_data[7:0];
                endcase
            end
        end
    end
end

endmodule

`default_nettype wire
