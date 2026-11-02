module banked_equivalence;
  reg [1:0] sp=0; reg [2:0] mp=0;
  reg [3:0] startup=0;
  always @($global_clock) begin
    sp <= sp+1;
    mp <= mp==5 ? 0 : mp+1;
    if (startup!=15) startup<=startup+1;
  end
  wire sclk=sp[1], mclk=mp>=3, rst=startup<8;
  (* anyseq *) reg [1:0] data;
  (* anyseq *) reg valid,last,ready;
  wire rs,bs,rv,bv,rl,bl; wire [1:0] rd,bd;
  reference_fifo #(.DEPTH(32),.DATA_WIDTH(2),.KEEP_ENABLE(0),
    .RAM_PIPELINE(2),.FRAME_FIFO(1),.DROP_BAD_FRAME(1)) reference (
    .s_clk(sclk),.s_rst(rst),.m_clk(mclk),.m_rst(rst),
    .s_axis_tdata(data),.s_axis_tkeep(1'b1),.s_axis_tvalid(valid),
    .s_axis_tready(rs),.s_axis_tlast(last),.s_axis_tuser(1'b0),
    .s_axis_tid(8'b0),.s_axis_tdest(8'b0),
    .m_axis_tdata(rd),.m_axis_tvalid(rv),.m_axis_tlast(rl),.m_axis_tready(ready),
    .s_pause_req(1'b0),.m_pause_req(1'b0));
  axis_async_fifo #(.DEPTH(32),.DATA_WIDTH(2),.KEEP_ENABLE(0),
    .RAM_PIPELINE(2),.FRAME_FIFO(1),.DROP_BAD_FRAME(1)) banked (
    .s_clk(sclk),.s_rst(rst),.m_clk(mclk),.m_rst(rst),
    .s_axis_tdata(data),.s_axis_tkeep(1'b1),.s_axis_tvalid(valid),
    .s_axis_tready(bs),.s_axis_tlast(last),.s_axis_tuser(1'b0),
    .s_axis_tid(8'b0),.s_axis_tdest(8'b0),
    .m_axis_tdata(bd),.m_axis_tvalid(bv),.m_axis_tlast(bl),.m_axis_tready(ready),
    .s_pause_req(1'b0),.m_pause_req(1'b0));
  reg past_s=0; reg [3:0] transfers=0;
  always @(posedge sclk) begin
    past_s<=1;
    if (!rst) assert(rs==bs);
    if (past_s && !rst && !$past(rst) && $past(valid && !rs)) begin
      assume(valid); assume($stable(data)); assume($stable(last));
    end
  end
  always @(posedge mclk) begin
    if (!rst) begin
      assert(rv==bv);
      if (rv) begin assert(rd==bd); assert(rl==bl); end
      if (rv && ready) transfers<=transfers+1;
      cover(rv && ready && rl && transfers>=2);
    end
  end
endmodule
