module ram (
    input logic clk,
    input logic [11:0] address,
    input logic [7:0] writeData,
    input logic writeEnabled,
    output logic [7:0] readData
);
    logic [7:0] memory [0:4095];
    always_ff @(posedge clk) begin
        if (writeEnabled)
            memory[address] <= writeData;
        readData <= memory[address];
    end
endmodule
