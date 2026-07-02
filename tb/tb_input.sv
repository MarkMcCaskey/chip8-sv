// Input testbench for chip8_cpu (M7). Drives the 16-key `buttons` vector from
// the tb and checks Ex9E / ExA1 in both directions plus the full Fx0A
// press-store-release protocol. Run with: make input
//
// Program:
//   200: 6C05  VC = 5
//   202: EC9E  skip if key 5 down   (up -> NOT taken)
//   204: 6101  V1 = 1               (proves fallthrough)
//   206: ECA1  skip if key 5 up     (up -> taken)
//   208: 62AA  V2 = 0xAA            (SKIPPED)
//   20A: 6201  V2 = 1
//   20C: F30A  V3 = wait for key    (tb presses/holds/releases key 9)
//   20E: 6401  V4 = 1               (only after the release)
//   210: E39E  skip if key V3(9) down   <- poll loop until tb presses again
//   212: 1210  loop to 210
//   214: 6501  V5 = 1               (Ex9E taken)
//   216: E3A1  skip if key 9 up     (held -> NOT taken)
//   218: 6601  V6 = 1               (proves fallthrough)
//   21A: 121A  halt
//
// The Fx0A phase asserts three things the final state can't show on its own:
// the CPU parks at PC=0x20E while no key is down, stores V3=9 at the moment of
// the press, and does NOT proceed (V4 stays 0) for as long as the key is held.
module tb_input;
    logic        clk;
    logic        rst;
    logic [15:0] buttons;
    logic        sound_on;
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
        $display("INPUT FAIL: watchdog timeout (CPU wedged?)");
        $fatal;
    end

    task automatic check(string name, logic [15:0] got, logic [15:0] exp);
        if (got !== exp) begin
            $error("%s = 0x%03h, expected 0x%03h", name, got, exp);
            errors++;
        end
    endtask

    task automatic put(input logic [11:0] a, input logic [15:0] op);
        dut.u_ram.memory[a]     = op[15:8];
        dut.u_ram.memory[a + 1] = op[7:0];
    endtask

    initial begin
        $dumpfile("tb_input.vcd");
        $dumpvars(0, tb_input);
        errors  = 0;
        buttons = '0;

        put(12'h200, 16'h6C05);
        put(12'h202, 16'hEC9E);
        put(12'h204, 16'h6101);
        put(12'h206, 16'hECA1);
        put(12'h208, 16'h62AA);
        put(12'h20A, 16'h6201);
        put(12'h20C, 16'hF30A);
        put(12'h20E, 16'h6401);
        put(12'h210, 16'hE39E);
        put(12'h212, 16'h1210);
        put(12'h214, 16'h6501);
        put(12'h216, 16'hE3A1);
        put(12'h218, 16'h6601);
        put(12'h21A, 16'h121A);

        rst = 1'b1;
        repeat (2) @(negedge clk);
        rst = 1'b0;

        // Fx0A executed: PC has moved to 0x20E but the FSM is parked waiting
        // for a press. Give it 30 idle cycles -- nothing may move.
        wait (dut.PC == 12'h20E);
        repeat (30) @(negedge clk);
        check("PC parked during wait", 16'(dut.PC),   16'h20E);
        check("V4 not yet set",        16'(dut.V[4]), 16'h00);

        // Press key 9 and hold it. The key must be stored immediately, but
        // execution must NOT resume until release.
        buttons[9] = 1'b1;
        repeat (30) @(negedge clk);
        check("V3 stored on press",  16'(dut.V[3]), 16'h09);
        check("PC parked while held",16'(dut.PC),   16'h20E);
        check("V4 still not set",    16'(dut.V[4]), 16'h00);

        // Release: V4=1 executes and the program enters the Ex9E poll loop.
        buttons[9] = 1'b0;
        repeat (40) @(negedge clk);
        check("resumed after release V4", 16'(dut.V[4]), 16'h01);
        check("poll loop not escaped V5", 16'(dut.V[5]), 16'h00);

        // Press again: Ex9E-taken and ExA1-not-taken paths run to the halt.
        buttons[9] = 1'b1;
        wait (dut.PC == 12'h21A);
        @(negedge clk);
        check("Ex9E not-taken  V1", 16'(dut.V[1]), 16'h01);
        check("ExA1 taken      V2", 16'(dut.V[2]), 16'h01);
        check("Ex9E taken      V5", 16'(dut.V[5]), 16'h01);
        check("ExA1 not-taken  V6", 16'(dut.V[6]), 16'h01);
        check("PC (halt)",          16'(dut.PC),   16'h21A);

        if (errors == 0)
            $display("INPUT PASS: Ex9E/ExA1 both directions + Fx0A press/hold/release protocol");
        else
            $display("INPUT FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
