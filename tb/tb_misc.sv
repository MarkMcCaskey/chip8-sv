// Misc-Fx testbench for chip8_cpu (M8): Fx33 BCD, Fx55 store, Fx65 load (and
// their VIP I = I + x + 1 side effect), Fx1E, Fx29 + the font ROM, and Cxkk
// randomness. Run with: make misc
//
// The ops are chained so they verify each other: Fx33 writes the BCD digits of
// 234 to memory, then Fx65 loads those same bytes back into V0..V2 -- if either
// half is broken the register checks fail. I-register side effects are sampled
// at PC checkpoints because later opcodes clobber I.
//
// Program:
//   200: A400  I = 0x400
//   202: 60EA  V0 = 234
//   204: F033  mem[400..402] = 2,3,4
//   206: A400  I = 0x400
//   208: F265  V0..V2 = 2,3,4;  I -> 0x403   <- checkpoint @PC=0x20C
//   20A: 6355  V3 = 0x55
//   20C: A480  I = 0x480
//   20E: F355  mem[480..483] = 02 03 04 55;  I -> 0x484   <- checkpoint @PC=0x212
//   210: CEFF  VE = rnd & FF
//   212: C4FF  V4 = rnd & FF     (sampled 20 LFSR steps later -> differs from VE)
//   214: C50F  V5 = rnd & 0F     (high nibble must be clean)
//   216: A100  I = 0x100
//   218: 6622  V6 = 0x22
//   21A: F61E  I += V6 -> 0x122               <- checkpoint @PC=0x21E
//   21C: 6700  V7 = 0
//   21E: 680A  V8 = 0x0A
//   220: F829  I = font('A') = 50
//   222: D775  draw glyph 'A' at (0,0), 5 rows
//   224: 1224  halt
module tb_misc;
    logic        clk;
    logic        rst;
    logic [15:0] buttons;
    // verilator lint_off UNUSEDSIGNAL
    logic        sound_on;   // dumped to the VCD; only tb_timer asserts on it
    // verilator lint_on UNUSEDSIGNAL
    int          errors;

    chip8_cpu #(.CYCLES_PER_TICK(16)) dut (
        .clk      (clk),
        .rst      (rst),
        .buttons  (buttons),
        .sound_on (sound_on)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        #100000;
        $display("MISC FAIL: watchdog timeout (CPU wedged?)");
        $fatal;
    end

    task automatic check(string name, logic [63:0] got, logic [63:0] exp);
        if (got !== exp) begin
            $error("%s = 0x%016h, expected 0x%016h", name, got, exp);
            errors++;
        end
    endtask

    task automatic put(input logic [11:0] a, input logic [15:0] op);
        dut.u_ram.memory[a]     = op[15:8];
        dut.u_ram.memory[a + 1] = op[7:0];
    endtask

    initial begin
        $dumpfile("tb_misc.vcd");
        $dumpvars(0, tb_misc);
        errors  = 0;
        buttons = '0;

        put(12'h200, 16'hA400);
        put(12'h202, 16'h60EA);
        put(12'h204, 16'hF033);
        put(12'h206, 16'hA400);
        put(12'h208, 16'hF265);
        put(12'h20A, 16'h6355);
        put(12'h20C, 16'hA480);
        put(12'h20E, 16'hF355);
        put(12'h210, 16'hCEFF);
        put(12'h212, 16'hC4FF);
        put(12'h214, 16'hC50F);
        put(12'h216, 16'hA100);
        put(12'h218, 16'h6622);
        put(12'h21A, 16'hF61E);
        put(12'h21C, 16'h6700);
        put(12'h21E, 16'h680A);
        put(12'h220, 16'hF829);
        put(12'h222, 16'hD775);
        put(12'h224, 16'h1224);

        rst = 1'b1;
        repeat (2) @(negedge clk);
        rst = 1'b0;

        // Fx65 finished (the instruction after it has executed): I bumped.
        wait (dut.PC == 12'h20C);
        @(negedge clk);
        check("Fx65 leaves I=x+I+1", 64'(dut.I), 64'h403);

        // Fx55 finished: same side effect.
        wait (dut.PC == 12'h212);
        @(negedge clk);
        check("Fx55 leaves I=x+I+1", 64'(dut.I), 64'h484);

        // Fx1E, before Fx29 clobbers I.
        wait (dut.PC == 12'h21E);
        @(negedge clk);
        check("Fx1E I += V6", 64'(dut.I), 64'h122);

        // Halt reached; let the trailing draw's DRAW_* states finish.
        wait (dut.PC == 12'h224);
        repeat (40) @(negedge clk);

        check("BCD hundreds mem[400]", 64'(dut.u_ram.memory[12'h400]), 64'd2);
        check("BCD tens     mem[401]", 64'(dut.u_ram.memory[12'h401]), 64'd3);
        check("BCD ones     mem[402]", 64'(dut.u_ram.memory[12'h402]), 64'd4);
        check("Fx65 loaded V0", 64'(dut.V[0]), 64'd2);
        check("Fx65 loaded V1", 64'(dut.V[1]), 64'd3);
        check("Fx65 loaded V2", 64'(dut.V[2]), 64'd4);
        check("Fx55 wrote mem[480]", 64'(dut.u_ram.memory[12'h480]), 64'h02);
        check("Fx55 wrote mem[481]", 64'(dut.u_ram.memory[12'h481]), 64'h03);
        check("Fx55 wrote mem[482]", 64'(dut.u_ram.memory[12'h482]), 64'h04);
        check("Fx55 wrote mem[483]", 64'(dut.u_ram.memory[12'h483]), 64'h55);
        check("Cxkk masks high nibble", 64'(dut.V[5] & 8'hF0), 64'd0);
        if (dut.V[14] == dut.V[4]) begin
            $error("Cxkk: two draws gave the same value 0x%02h", dut.V[4]);
            errors++;
        end
        // Fx29 + font ROM + draw: glyph 'A' (F0 90 F0 90 90) in the corner.
        check("font A row 0", dut.fb[0], 64'hF000_0000_0000_0000);
        check("font A row 1", dut.fb[1], 64'h9000_0000_0000_0000);
        check("font A row 2", dut.fb[2], 64'hF000_0000_0000_0000);
        check("font A row 3", dut.fb[3], 64'h9000_0000_0000_0000);
        check("font A row 4", dut.fb[4], 64'h9000_0000_0000_0000);
        check("PC (halt)", 64'(dut.PC), 64'h224);

        if (errors == 0)
            $display("MISC PASS: BCD/store/load/I-increment/Fx1E/font/random all correct");
        else
            $display("MISC FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
