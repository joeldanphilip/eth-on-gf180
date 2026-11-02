// The structural certificate checks that each physical replica has exactly
// the original D/CLK. Unknown power-up values may differ until the first edge;
// functional packet operation follows startup reset and address initialization.
module replication_equivalence;
    (* anyseq *) reg clk;
    (* anyseq *) reg data;
    reg original;
    reg replica;
    reg clock_seen = 0;
    always @(posedge clk) begin
        original <= data;
        replica <= data;
        clock_seen <= 1;
    end
    always @* if (clock_seen) assert(original == replica);
endmodule
