module fixed_priority #(
    parameter PORTS = 8
) (
    input logic[PORTS-1:0]  request,
    output logic[PORTS-1:0] grant
);

logic[PORTS-1:0] grant_temp;

assign grant = grant_temp;
// Priority one-hot grant
always_comb begin
    grant_temp[0] = request[0];
    for (int i = 1; i < PORTS; i++) begin
        grant_temp[i] = request[i] & ~(|grant_temp[i-1:0]);
    end 
end
endmodule
