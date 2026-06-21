// Testbench for chip8_cpu -- exercises the fetch/decode/execute path and the
// opcodes implemented so far. Loads a small program into the CPU-owned RAM via
// a hierarchical reference (the RAM has no external load port), runs it, and
// checks the register/PC end state. Run with: make cpu
//
// Program (loaded at 0x200; CHIP-8 is big-endian, so the byte at PC is the high
// byte of the opcode):
//   200: 61 11   V1 = 0x11        (known value, so the skip below is observable)
//   202: 60 05   V0 = 0x05
//   204: 70 03   V0 += 0x03       -> V0 = 0x08
//   206: A1 23   I  = 0x123
//   208: 30 08   skip next if V0 == 0x08   (true -> skips 0x20A)
//   20A: 61 AA   V1 = 0xAA        (SKIPPED -> V1 stays 0x11)
//   20C: 62 BB   V2 = 0xBB
//   20E: 12 0E   jump 0x20E       (jump-to-self = halt)
module tb_cpu;
    logic       clk;
    logic       rst;
    logic [4:0] buttons;
    int         errors;

    chip8_cpu dut (
        .clk     (clk),
        .rst     (rst),
        .buttons (buttons)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Compare a DUT signal against an expected value. Widened to 16 bits so the
    // same helper works for V (8b), PC (12b), and I (16b).
    task automatic check(string name, logic [15:0] got, logic [15:0] exp);
        if (got !== exp) begin
            $error("%s = 0x%03h, expected 0x%03h", name, got, exp);
            errors++;
        end
    endtask

    initial begin
        $dumpfile("tb_cpu.vcd");
        $dumpvars(0, tb_cpu);
        errors  = 0;
        buttons = '0;

        // Load the program straight into the CPU's RAM (hierarchical write).
        dut.u_ram.memory[12'h200] = 8'h61;
        dut.u_ram.memory[12'h201] = 8'h11;
        dut.u_ram.memory[12'h202] = 8'h60;
        dut.u_ram.memory[12'h203] = 8'h05;
        dut.u_ram.memory[12'h204] = 8'h70;
        dut.u_ram.memory[12'h205] = 8'h03;
        dut.u_ram.memory[12'h206] = 8'hA1;
        dut.u_ram.memory[12'h207] = 8'h23;
        dut.u_ram.memory[12'h208] = 8'h30;
        dut.u_ram.memory[12'h209] = 8'h08;
        dut.u_ram.memory[12'h20A] = 8'h61;
        dut.u_ram.memory[12'h20B] = 8'hAA;
        dut.u_ram.memory[12'h20C] = 8'h62;
        dut.u_ram.memory[12'h20D] = 8'hBB;
        dut.u_ram.memory[12'h20E] = 8'h12;
        dut.u_ram.memory[12'h20F] = 8'h0E;

        // Reset.
        rst = 1'b1;
        repeat (2) @(negedge clk);
        rst = 1'b0;

        // Run well past the 7 instructions (~28 cycles); halt loop holds state.
        repeat (80) @(negedge clk);

        // End-state checks.
        check("V0", 16'(dut.V[0]), 16'h008);
        check("V1", 16'(dut.V[1]), 16'h011);   // 0x11, not 0xAA -> the skip worked
        check("V2", 16'(dut.V[2]), 16'h0BB);
        check("I",  16'(dut.I),    16'h123);
        check("PC", 16'(dut.PC),   16'h20E);

        if (errors == 0)
            $display("CPU PASS: program executed correctly");
        else
            $display("CPU FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
