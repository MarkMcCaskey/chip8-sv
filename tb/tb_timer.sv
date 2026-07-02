// Timer testbench for chip8_cpu (M5). Overrides CYCLES_PER_TICK down to 16 so
// a "60 Hz" tick fires every 4 instructions and the whole test runs in a few
// hundred cycles. Run with: make timer
//
// What's checked:
//   * Fx15 sets the delay timer and Fx07 reads it straight back (the read
//     lands before the first tick at cycle 16, so the value is exact)
//   * Fx18 sets the sound timer and sound_on goes high while it's nonzero
//   * both timers count down at the tick rate and STOP at zero (no wrap):
//     the final checks run ~25 ticks in, long after both hit zero
//
// Program:
//   200: 6A08  VA = 8
//   202: FA15  delay = VA (8)
//   204: F107  V1 = delay          -> 8, read before any tick
//   206: FA18  sound = VA (8)
//   208: F007  V0 = delay          <- poll loop
//   20A: 3000  skip next if V0 == 0
//   20C: 1208  loop back to 208
//   20E: 6C01  VC = 1              (delay reached zero)
//   210: 1210  halt
module tb_timer;
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
        $dumpfile("tb_timer.vcd");
        $dumpvars(0, tb_timer);
        errors  = 0;
        buttons = '0;

        put(12'h200, 16'h6A08);
        put(12'h202, 16'hFA15);
        put(12'h204, 16'hF107);
        put(12'h206, 16'hFA18);
        put(12'h208, 16'hF007);
        put(12'h20A, 16'h3000);
        put(12'h20C, 16'h1208);
        put(12'h20E, 16'h6C01);
        put(12'h210, 16'h1210);

        rst = 1'b1;
        repeat (2) @(negedge clk);
        rst = 1'b0;

        // Mid-flight: sound was set to 8 around cycle 16 and won't hit zero
        // until ~cycle 144, so at cycle 40 the buzzer must be on.
        repeat (40) @(negedge clk);
        check("sound_on while counting", 16'(sound_on), 16'h1);

        // 400 cycles = 25 ticks: both timers are long past zero. If they
        // wrapped instead of saturating, they'd read nonzero here.
        repeat (360) @(negedge clk);
        check("Fx07 straight readback V1", 16'(dut.V[1]), 16'h08);
        check("delay reached zero    VC", 16'(dut.V[12]), 16'h01);
        check("Fx07 read of zero     V0", 16'(dut.V[0]),  16'h00);
        check("delay_timer stopped at 0", 16'(dut.delay_timer), 16'h00);
        check("sound_timer stopped at 0", 16'(dut.sound_timer), 16'h00);
        check("sound_on off at zero",     16'(sound_on), 16'h0);
        check("PC (halt)", 16'(dut.PC), 16'h210);

        if (errors == 0)
            $display("TIMER PASS: delay/sound count down at tick rate and saturate at 0");
        else
            $display("TIMER FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
