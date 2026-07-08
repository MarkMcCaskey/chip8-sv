// Module: round_robin
// Implements a round_robin arbiter with parameterized number of ports
module round_robin #(
    parameter PORTS = 4
) (

    input logic             clk,
    input logic             rst,

    input logic[PORTS-1:0]  request,
    output logic[PORTS-1:0] grant
);

logic[PORTS-1:0] priority_grant, masked_grant, mask_reg, mask_next;
logic[PORTS-1:0] masked_request;
logic[PORTS-1:0] grant_temp;


assign grant = grant_temp;
assign grant_temp = (|masked_grant) ? masked_grant : priority_grant;
assign masked_request = request & mask_reg;

fixed_priority #(
    .PORTS      (PORTS)
) priority_grant_i (
    .request    (request),
    .grant      (priority_grant)
);

fixed_priority #(
    .PORTS      (PORTS)
) masked_grant_i (
    .request    (masked_request),
    .grant      (masked_grant)
);

always_ff @(posedge clk) begin
    if (rst) begin
        mask_reg <= '1;
    end else begin
        mask_reg <= mask_next;
    end
end


// Grant is always one-hot
// Create a mask for the masked request.
// Grant will always rotate because the mask is being generated from the output (which may also be masked)
always_comb begin
    mask_next = mask_reg;
    if (grant_temp[PORTS-1]) begin
        mask_next = '1;
    end else begin
        for (int i = 0; i < PORTS - 1; i++) begin
            if (grant_temp[i]) begin
                mask_next = ~((grant_temp << 1) - 1);
            end
        end
    end
end

endmodule
