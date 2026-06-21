module chip8_cpu (
    input logic clk,
    input logic rst,
    input logic [4:0] buttons
);
    logic [7:0] V [0:15];
    logic [11:0] PC;
    logic [15:0] I;
    logic [3:0] SP;
    logic [11:0] stack [0:15];

    logic [11:0] mem_addr;
    logic [7:0] mem_wdata;
    logic mem_we;
    logic [7:0] mem_rdata; 

    ram u_ram (
        .clk (clk),
        .address (mem_addr),
        .writeData (mem_wdata),
        .writeEnabled (mem_we),
        .readData (mem_rdata)
    );
    logic [15:0] opcode;

    typedef enum logic [1:0] { PRIME, FETCH_HI, FETCH_LO, EXEC } state_t;
    state_t state;

    always_comb begin
        mem_addr = PC;
        mem_we = 1'b0;
        if (state == FETCH_HI)
            mem_addr = PC + 1;
        else if (state == FETCH_LO)
            mem_addr = PC;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            PC <= 12'h200;
            state <= PRIME;
            SP <= 4'd0;
            // TODO: init other values here
            end
        else begin
            if (state == PRIME) begin
                state <= FETCH_HI;
                end
            else if (state == FETCH_HI) begin
                opcode[15:8] <= mem_rdata;
                state <= FETCH_LO;
                end
            else if (state == FETCH_LO) begin
                opcode[7:0] <= mem_rdata;
                state <= EXEC;
                end
            else if (state == EXEC) begin
                logic [3:0] topNibble;
                logic [3:0] secondNibble;
                logic [3:0] thirdNibble;
                logic [3:0] fourthNibble;
                topNibble = opcode[15:12];
                secondNibble = opcode[11:8];
                thirdNibble = opcode[7:4];
                fourthNibble = opcode[3:0];

                PC <= PC + 2;

                if (topNibble == 4'h1) begin
                    PC <= (opcode[11:0] & 12'hFFF);
                    end
                else if (topNibble == 4'h2) begin
                    SP <= SP + 1;
                    stack[SP] <= PC + 2;
                    PC <= (opcode[11:0] & 12'hFFF);
                    end
                else if (topNibble == 4'h3) begin
                    if (V[secondNibble] == (opcode[7:0]))
                        PC <= PC + 4;
                    end
                else if (topNibble == 4'h4) begin
                    if (V[secondNibble] != (opcode[7:0]))
                        PC <= PC + 4;
                    end
                else if (topNibble == 4'h5) begin
                    if (V[secondNibble] == V[thirdNibble])
                        PC <= PC + 4;
                    end
                else if (topNibble == 4'h6) begin
                    V[secondNibble] <= (opcode[7:0]);
                    end
                else if (topNibble == 4'h7) begin
                    V[secondNibble] <= V[secondNibble] + (opcode[7:0]);
                    end
                else if (topNibble == 4'h8) begin
                    if (fourthNibble == 0)
                        V[secondNibble] <= V[thirdNibble];
                    else if (fourthNibble == 1)
                        V[secondNibble] <=  V[secondNibble] | V[thirdNibble];
                    else if (fourthNibble == 2)
                        V[secondNibble] <=  V[secondNibble] & V[thirdNibble];
                    else if (fourthNibble == 3)
                        V[secondNibble] <=  V[secondNibble] ^ V[thirdNibble];
                    else if (fourthNibble == 4) // TODO: set VF for carry
                        V[secondNibble] <=  V[secondNibble] + V[thirdNibble];
                    end
                else if (topNibble == 4'hA) begin
                    I <= opcode & 12'hFFF;
                    end
                else if (topNibble == 4'hB)
                    PC <= (opcode[11:0] & 12'hFFF) + V[0];
                state <= PRIME;
                end
            end
    end

endmodule

