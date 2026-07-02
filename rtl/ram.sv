module ram (
    input logic clk,
    input logic [11:0] address,
    input logic [7:0] writeData,
    input logic writeEnabled,
    output logic [7:0] readData
);
    logic [7:0] memory [0:4095];

    // Standard CHIP-8 hex font: sixteen 5-byte glyphs (0-F) at 0x000, where
    // Fx29 (I = Vx * 5) expects them. Block-RAM-style init, synthesizable.
    localparam logic [7:0] FONT [0:79] = '{
        8'hF0, 8'h90, 8'h90, 8'h90, 8'hF0,   // 0
        8'h20, 8'h60, 8'h20, 8'h20, 8'h70,   // 1
        8'hF0, 8'h10, 8'hF0, 8'h80, 8'hF0,   // 2
        8'hF0, 8'h10, 8'hF0, 8'h10, 8'hF0,   // 3
        8'h90, 8'h90, 8'hF0, 8'h10, 8'h10,   // 4
        8'hF0, 8'h80, 8'hF0, 8'h10, 8'hF0,   // 5
        8'hF0, 8'h80, 8'hF0, 8'h90, 8'hF0,   // 6
        8'hF0, 8'h10, 8'h20, 8'h40, 8'h40,   // 7
        8'hF0, 8'h90, 8'hF0, 8'h90, 8'hF0,   // 8
        8'hF0, 8'h90, 8'hF0, 8'h10, 8'hF0,   // 9
        8'hF0, 8'h90, 8'hF0, 8'h90, 8'h90,   // A
        8'hE0, 8'h90, 8'hE0, 8'h90, 8'hE0,   // B
        8'hF0, 8'h80, 8'h80, 8'h80, 8'hF0,   // C
        8'hE0, 8'h90, 8'h90, 8'h90, 8'hE0,   // D
        8'hF0, 8'h80, 8'hF0, 8'h80, 8'hF0,   // E
        8'hF0, 8'h80, 8'hF0, 8'h80, 8'h80    // F
    };

    initial begin
        for (int i = 0; i < 80; i++)
            memory[i] = FONT[i];
    end

    always_ff @(posedge clk) begin
        if (writeEnabled)
            memory[address] <= writeData;
        readData <= memory[address];
    end
endmodule
