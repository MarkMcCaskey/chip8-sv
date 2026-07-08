// Module: rom
// Useful as a ROM for simulation
module rom #(
    parameter  FILE       = "NONE",
    parameter  DEPTH      = 1024,
    parameter  DATA_WIDTH = 32,
    localparam ADDR_WIDTH = $clog2(DEPTH)
) (
    input  logic                  clk,
    input  logic[ADDR_WIDTH-1:0]  addr,
    input  logic                  rd_en,
    output logic[DATA_WIDTH-1:0]  data
);

logic[DATA_WIDTH-1:0] rom[DEPTH];

initial $readmemh(FILE, rom);

always_ff @(posedge clk) begin
    if (rd_en) begin
        data <= rom[addr];
    end
end

endmodule
