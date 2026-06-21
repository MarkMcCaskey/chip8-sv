// Warm-up DUT: an 8-bit up-counter.
// Synchronous, active-high reset; counts only when `en` is asserted.
// Nothing to do with CHIP-8 yet -- this exists only to prove the toolchain.
module counter (
    input  logic       clk,
    input  logic       rst,    // synchronous, active high
    input  logic       en,     // count enable
    output logic [7:0] count
);
    always_ff @(posedge clk) begin
        if (rst)
            count <= 8'd0;
        else if (en)
            count <= count + 8'd1;
    end
endmodule
