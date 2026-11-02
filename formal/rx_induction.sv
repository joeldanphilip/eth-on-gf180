module rx_induction(input clk);
  reg [1:0] startup=0;
  always @(posedge clk) if(startup!=3) startup<=startup+1;
  wire rst=startup<2;
  (* anyseq *) reg [7:0] data;
  (* anyseq *) reg dv,er,enable,mii,cfg;
  wire [7:0] rd,nd;
  wire rv,nv,rl,nl,ru,nu,rs,ns,rf,nf,rc,nc;
  wire [51:0] rp,np;
  wire [2:0] rstate,nstate;
  wire [31:0] ref_crc_next,new_crc_state;
  reference_rx reference(.clk(clk),.rst(rst),.gmii_rxd(data),.gmii_rx_dv(dv),.gmii_rx_er(er),
    .m_axis_tdata(rd),.m_axis_tvalid(rv),.m_axis_tlast(rl),.m_axis_tuser(ru),
    .ptp_ts(96'b0),.clk_enable(enable),.mii_select(mii),.cfg_rx_enable(cfg),
    .start_packet(rs),.error_bad_frame(rf),.error_bad_fcs(rc),
    .crc_next(ref_crc_next),.state_reg(rstate),
    .gmii_rxd_d0(rp[7:0]),.gmii_rxd_d1(rp[15:8]),.gmii_rxd_d2(rp[23:16]),
    .gmii_rxd_d3(rp[31:24]),.gmii_rxd_d4(rp[39:32]),
    .gmii_rx_dv_d0(rp[40]),.gmii_rx_dv_d1(rp[41]),.gmii_rx_dv_d2(rp[42]),
    .gmii_rx_dv_d3(rp[43]),.gmii_rx_dv_d4(rp[44]),
    .gmii_rx_er_d0(rp[45]),.gmii_rx_er_d1(rp[46]),.gmii_rx_er_d2(rp[47]),
    .gmii_rx_er_d3(rp[48]),.gmii_rx_er_d4(rp[49]),.mii_odd(rp[50]),.in_frame(rp[51]));
  axis_gmii_rx candidate(.clk(clk),.rst(rst),.gmii_rxd(data),.gmii_rx_dv(dv),.gmii_rx_er(er),
    .m_axis_tdata(nd),.m_axis_tvalid(nv),.m_axis_tlast(nl),.m_axis_tuser(nu),
    .ptp_ts(96'b0),.clk_enable(enable),.mii_select(mii),.cfg_rx_enable(cfg),
    .start_packet(ns),.error_bad_frame(nf),.error_bad_fcs(nc),
    .crc_state(new_crc_state),.state_reg(nstate),
    .gmii_rxd_d0(np[7:0]),.gmii_rxd_d1(np[15:8]),.gmii_rxd_d2(np[23:16]),
    .gmii_rxd_d3(np[31:24]),.gmii_rxd_d4(np[39:32]),
    .gmii_rx_dv_d0(np[40]),.gmii_rx_dv_d1(np[41]),.gmii_rx_dv_d2(np[42]),
    .gmii_rx_dv_d3(np[43]),.gmii_rx_dv_d4(np[44]),
    .gmii_rx_er_d0(np[45]),.gmii_rx_er_d1(np[46]),.gmii_rx_er_d2(np[47]),
    .gmii_rx_er_d3(np[48]),.gmii_rx_er_d4(np[49]),.mii_odd(np[50]),.in_frame(np[51]));
  always @(posedge clk) if(!rst) begin
    assert(rp==np); assert(rstate==nstate);
    if(rstate==1) assert(new_crc_state==ref_crc_next);
    assert(rv==nv); assert(rs==ns); assert(rf==nf); assert(rc==nc);
    if(rv) begin assert(rd==nd); assert(rl==nl); assert(ru==nu); end
    cover(rv && rl && !ru);
  end
endmodule
