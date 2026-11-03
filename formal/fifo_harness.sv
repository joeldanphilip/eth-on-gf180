// Reduced FIFO configuration; independent clocks may advance or stop arbitrarily.
module fifo_harness;
`ifdef PERIODIC_CLOCKS
  reg [1:0] source_phase=0;
  reg [2:0] sink_phase=0;
  always @($global_clock) begin
    source_phase <= source_phase + 1;
    sink_phase <= sink_phase == 5 ? 0 : sink_phase + 1;
  end
  wire s_clk=source_phase[1], m_clk=(sink_phase >= 3);
`else
  (* anyseq *) reg s_clk, m_clk;
`endif
  reg [3:0] startup = 0;
  always @($global_clock) if (startup != 15) startup <= startup + 1;
  wire rst = startup < 8;
`ifdef ELASTIC_READ
  localparam FORMAL_DATA_WIDTH=2;
`else
  localparam FORMAL_DATA_WIDTH=8;
`endif
  (* anyseq *) reg [FORMAL_DATA_WIDTH-1:0] data;
  (* anyseq *) reg valid, ready, last;
  wire sr, mv, ml; wire [FORMAL_DATA_WIDTH-1:0] md;
`ifdef DEEP_READ_PIPELINE
  localparam FORMAL_PIPELINE=3;
`elsif REGISTER_FULL_FLAGS
  localparam FORMAL_PIPELINE=2;
`else
  localparam FORMAL_PIPELINE=1;
`endif
`ifdef FRAME_MODE
  localparam FRAME_ENABLE=1;
  // Restrict frames to one or two beats so depth-four oversize drops cannot
  // invalidate the input/output prefix model. No bad-frame markers injected.
  reg frame_position=0;
  always @(posedge s_clk) begin
    if (rst) frame_position <= 0;
    else if (valid && sr) begin
      if (frame_position) assume(last);
      frame_position <= !last;
    end
  end
`else
  localparam FRAME_ENABLE=0;
`endif
`ifdef ELASTIC_READ
  localparam TEST_DEPTH=32;
`else
  localparam TEST_DEPTH=4;
`endif
  axis_async_fifo #(.DEPTH(TEST_DEPTH), .DATA_WIDTH(FORMAL_DATA_WIDTH), .KEEP_ENABLE(0),
    .RAM_PIPELINE(FORMAL_PIPELINE),
    .ID_ENABLE(0), .DEST_ENABLE(0), .USER_ENABLE(FRAME_ENABLE), .FRAME_FIFO(FRAME_ENABLE),
    .DROP_BAD_FRAME(FRAME_ENABLE)) dut (
    .s_clk(s_clk), .s_rst(rst), .m_clk(m_clk), .m_rst(rst),
    .s_axis_tdata(data), .s_axis_tkeep(1'b1), .s_axis_tvalid(valid),
    .s_axis_tready(sr), .s_axis_tlast(last), .s_axis_tid(8'b0),
    .s_axis_tdest(8'b0), .s_axis_tuser(1'b0),
    .m_axis_tdata(md), .m_axis_tvalid(mv), .m_axis_tready(ready),
    .m_axis_tlast(ml), .s_pause_req(1'b0), .m_pause_req(1'b0));
  reg spast=0, mpast=0;
  // Symbolic accepted-beat index: compare an arbitrary input beat with its
  // corresponding output beat, including TLAST. Counters cannot wrap in 30 steps.
  (* anyconst *) reg [7:0] selected;
  reg [7:0] writes=0, reads=0;
  reg [7:0] committed=0;
  reg [FORMAL_DATA_WIDTH:0] selected_beat;
  always @(posedge s_clk) begin
    spast <= 1;
    if (rst) begin writes <= 0; committed <= 0; end
    else if (valid && sr) begin
      writes <= writes + 1;
      if (last) committed <= writes + 1;
      if (writes == selected) selected_beat <= {last,data};
    end
    if (spast && !$past(rst) && !rst && $past(valid && !sr)) begin
      assume(valid); assume($stable(data)); assume($stable(last));
    end
`ifdef REGISTER_FULL_FLAGS
    if (!rst) cover(valid && !sr && writes>=5);
`endif
  end
  always @(posedge m_clk) begin
    mpast <= 1;
    if (rst) reads <= 0;
    else if (mv && ready) begin
      assert(reads < writes);
      if (FRAME_ENABLE) assert(reads < committed);
      if (reads == selected) assert({ml,md} == selected_beat);
      reads <= reads + 1;
    end
    if (mpast && !$past(rst) && !rst && $past(mv && !ready)) begin
      assert(mv); assert($stable(md)); assert($stable(ml));
    end
    if (!rst) begin
      cover(mv && ready && ml);
`ifdef FRAME_MODE
      cover(mv && ready && ml && reads >= 2);
`endif
    end
  end
endmodule
