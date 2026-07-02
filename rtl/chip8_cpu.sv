module chip8_cpu #(
    // CPU clock cycles per 60 Hz timer tick. The default assumes a ~500 kHz
    // core clock; testbenches override it with a tiny value so ticks are cheap.
    parameter int CYCLES_PER_TICK = 8333
) (
    input logic clk,
    input logic rst,
    input logic [15:0] buttons,
    output logic sound_on   // high while sound_timer > 0 (drives the buzzer)
);
    logic [7:0] V [0:15];
    logic [11:0] PC;
    logic [15:0] I;
    logic [3:0] SP;
    logic [11:0] stack [0:15];

    // 60 Hz tick divider + the two 8-bit timers it decrements.
    logic [31:0] tick_cnt;
    logic tick;
    logic [7:0] delay_timer;
    logic [7:0] sound_timer;

    assign tick = (tick_cnt == 32'(CYCLES_PER_TICK - 1));
    assign sound_on = (sound_timer != 8'd0);

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

    typedef enum logic [3:0] {
        PRIME, FETCH_HI, FETCH_LO, EXEC,
        DRAW_WAIT, DRAW_ADDR, DRAW_XOR
    } state_t;
    state_t state;

    // 64x32 monochrome framebuffer. Bit 63 of a row is x=0 (leftmost), so a
    // sprite byte lands with `{byte, 56'b0} >> x` and clips off the right edge
    // for free.
    logic [63:0] fb [0:31];
    logic [5:0] draw_x;
    logic [4:0] draw_y;
    logic [3:0] draw_n;
    logic [3:0] draw_r;

    always_comb begin
        mem_addr = PC;
        mem_we = 1'b0;
        if (state == FETCH_HI)
            mem_addr = PC + 1;
        else if (state == FETCH_LO)
            mem_addr = PC;
        else if (state == DRAW_ADDR || state == DRAW_XOR)
            mem_addr = 12'(I + 16'(draw_r));
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            PC <= 12'h200;
            state <= PRIME;
            SP <= 4'd0;
            tick_cnt <= 32'd0;
            delay_timer <= 8'd0;
            sound_timer <= 8'd0;
            for (int i = 0; i < 32; i++)
                fb[i] <= 64'd0;
            // TODO: init other values here
            end
        else begin
            // Timers run independently of the instruction FSM. A same-edge
            // Fx15/Fx18 write below overrides the decrement (write wins).
            tick_cnt <= tick ? 32'd0 : tick_cnt + 1;
            if (tick) begin
                if (delay_timer != 8'd0)
                    delay_timer <= delay_timer - 1;
                if (sound_timer != 8'd0)
                    sound_timer <= sound_timer - 1;
                end

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
                logic [7:0] bottomHalf;
                topNibble = opcode[15:12];
                secondNibble = opcode[11:8];
                thirdNibble = opcode[7:4];
                fourthNibble = opcode[3:0];
                bottomHalf = opcode[7:0];

                PC <= PC + 2;
                state <= PRIME;   // opcodes below may override (e.g. Dxyn)

                if (topNibble == 4'h0) begin
                    if (bottomHalf == 8'hE0) begin
                        for (int i = 0; i < 32; i++)
                            fb[i] <= 64'd0;
                        end
                    else if (bottomHalf == 8'hEE) begin
                        PC <= stack[SP - 1];
                        SP <= SP - 1;
                        end
                    end
                else if (topNibble == 4'h1) begin
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
                    else if (fourthNibble == 4) begin
                        logic [8:0] ninebitSum;
                        ninebitSum = 9'(V[secondNibble]) + 9'(V[thirdNibble]);
                        V[secondNibble] <= 8'(ninebitSum);
                        V[4'hF] <= 8'(ninebitSum[8]);
                        end
                    else if (fourthNibble == 5) begin
                        V[secondNibble] <= V[secondNibble] - V[thirdNibble];
                        V[4'hF] <= 8'(V[secondNibble] >= V[thirdNibble]);
                        end
                    else if (fourthNibble == 6) begin
                        V[secondNibble] <= V[secondNibble] >> 1;
                        V[4'hF] <= 8'(V[secondNibble][0]);
                        end
                    else if (fourthNibble == 7) begin
                        V[secondNibble] <=  V[thirdNibble] - V[secondNibble];
                        V[4'hF] <= 8'(V[secondNibble] <= V[thirdNibble]);
                        end
                    else if (fourthNibble == 4'hE) begin
                        V[secondNibble] <= V[secondNibble] << 1;
                        V[4'hF] <= 8'(V[secondNibble][7]);
                        end
                    end
                else if (topNibble == 4'h9) begin
                    if (V[secondNibble] != V[thirdNibble])
                        PC <= PC + 4;
                    end
                else if (topNibble == 4'hA) begin
                    I <= opcode & 16'h0FFF;
                    end
                else if (topNibble == 4'hB)
                    PC <= (opcode[11:0] & 12'hFFF) + 12'(V[0]);
                else if (topNibble == 4'hC) // TODO: random numbers somehow
                    V[secondNibble] <= (8'h77 & bottomHalf);
                else if (topNibble == 4'hD) begin
                    // Start coords wrap; the sprite itself clips at the edges
                    // (VIP behavior). Rows are fetched from mem[I..I+n-1] by
                    // the DRAW_* states, 2 cycles per row.
                    draw_x <= V[secondNibble][5:0];
                    draw_y <= V[thirdNibble][4:0];
                    draw_n <= fourthNibble;
                    draw_r <= 4'd0;
                    V[4'hF] <= 8'd0;
                    state <= DRAW_WAIT;
                    end
                else if (topNibble == 4'hE) begin
                    if (bottomHalf == 8'h9E) begin
                        if (buttons[4'(V[secondNibble])])
                            PC <= PC + 4;
                        end
                    else if (bottomHalf == 8'hA1) begin
                        if (!buttons[4'(V[secondNibble])])
                            PC <= PC + 4;
                        end
                    end
                else if (topNibble == 4'hF) begin
                    if (bottomHalf == 8'h07) begin
                        V[secondNibble] <= delay_timer;
                        end
                    else if (bottomHalf == 8'h0A) begin
                        end
                    else if (bottomHalf == 8'h15) begin
                        delay_timer <= V[secondNibble];
                        end
                    else if (bottomHalf == 8'h18) begin
                        sound_timer <= V[secondNibble];
                        end
                    else if (bottomHalf == 8'h1E) begin
                        I <= I + 16'(V[secondNibble]);
                        end
                    else if (bottomHalf == 8'h29) begin
                        I <= 16'(V[secondNibble]) * 5;
                        end
                    else if (bottomHalf == 8'h33) begin
                        end
                    else if (bottomHalf == 8'h55) begin
                        end
                    else if (bottomHalf == 8'h65) begin
                        end
                    end
                end
            // Dxyn tail: stall until the 60 Hz tick (VIP draws during vblank),
            // then 2 cycles per sprite row: present address, then XOR the byte.
            else if (state == DRAW_WAIT) begin
                if (tick)
                    state <= (draw_n == 4'd0) ? PRIME : DRAW_ADDR;
                end
            else if (state == DRAW_ADDR) begin
                state <= DRAW_XOR;
                end
            else if (state == DRAW_XOR) begin
                logic [63:0] spr_mask;
                logic [5:0] row_idx;
                spr_mask = {mem_rdata, 56'b0} >> draw_x;
                row_idx = 6'(draw_y) + 6'(draw_r);
                if (row_idx < 6'd32) begin   // clip at the bottom edge
                    if ((fb[row_idx[4:0]] & spr_mask) != 64'd0)
                        V[4'hF] <= 8'd1;
                    fb[row_idx[4:0]] <= fb[row_idx[4:0]] ^ spr_mask;
                    end
                draw_r <= draw_r + 1;
                state <= (4'(draw_r + 4'd1) == draw_n) ? PRIME : DRAW_ADDR;
                end
            end
    end

endmodule

