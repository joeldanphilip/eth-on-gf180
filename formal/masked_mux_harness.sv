module masked_mux_harness;
    localparam N = 16;
    localparam W = 10;
    (* anyconst *) reg [3:0] select;
    (* anyconst *) reg [N*W-1:0] words;
    wire [N-1:0] onehot = 16'b1 << select;
    reg [W-1:0] masked;
    integer i;
    always @* begin
        masked = 0;
        for (i=0; i<N; i=i+1)
            masked = masked | (words[i*W +: W] & {W{onehot[i]}});
        assert(masked == words[select*W +: W]);
    end
endmodule
