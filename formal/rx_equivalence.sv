module rx_equivalence(input clk);
  reg [1:0] startup=0;
  always @(posedge clk) if(startup!=3) startup<=startup+1;
  wire rst=startup<2;
  (* anyseq *) reg [7:0] data;
  (* anyseq *) reg dv,er,enable,mii,cfg;
  wire [7:0] rd,nd;
  wire rv,nv,rl,nl,ru,nu,rs,ns,rf,nf,rc,nc;
  reference_rx reference(.clk(clk),.rst(rst),.gmii_rxd(data),.gmii_rx_dv(dv),.gmii_rx_er(er),
    .m_axis_tdata(rd),.m_axis_tvalid(rv),.m_axis_tlast(rl),.m_axis_tuser(ru),
    .ptp_ts(96'b0),.clk_enable(enable),.mii_select(mii),.cfg_rx_enable(cfg),
    .start_packet(rs),.error_bad_frame(rf),.error_bad_fcs(rc));
  axis_gmii_rx candidate(.clk(clk),.rst(rst),.gmii_rxd(data),.gmii_rx_dv(dv),.gmii_rx_er(er),
    .m_axis_tdata(nd),.m_axis_tvalid(nv),.m_axis_tlast(nl),.m_axis_tuser(nu),
    .ptp_ts(96'b0),.clk_enable(enable),.mii_select(mii),.cfg_rx_enable(cfg),
    .start_packet(ns),.error_bad_frame(nf),.error_bad_fcs(nc));
  always @(posedge clk) if(!rst) begin
    assert(rv==nv); assert(rs==ns); assert(rf==nf); assert(rc==nc);
    if(rv) begin assert(rd==nd); assert(rl==nl); assert(ru==nu); end
    cover(rv && rl && !ru);
  end
endmodule
