module ram #(
    parameter WIDTH = 8,
    parameter DEPTH = 4096
) (
    input logic                     clk,
    input logic [$clog2(DEPTH)-1:0] address,

    input logic [WIDTH-1:0]         writeData,
    input logic                     writeEnabled,
    output logic [WIDTH-1:0]        readData
);
    logic [WIDTH-1:0] memory [DEPTH-1];
    always_ff @(posedge clk) begin
        if (writeEnabled)
            memory[address] <= writeData;
        readData <= memory[address];
    end
endmodule
