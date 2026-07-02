// Display testbench for chip8_cpu (M6). Checks Dxyn against exact framebuffer
// contents, not just VF: draw, XOR self-erase with collision, clipping at the
// right and bottom edges, start-coordinate wrap, and 00E0 clear. Run with:
// make display
//
// CYCLES_PER_TICK is dropped to 16 so the VIP-style "wait for vblank before
// drawing" stall costs at most 16 cycles per Dxyn.
//
// The tb samples mid-program by waiting for PC to reach a checkpoint address
// (the fb rows being checked are stable by then), so intermediate states are
// verified before 00E0 wipes them.
//
// Program ("sprite A" = FF 81 FF at 0x300 — a 8x3 open box):
//   200: A300  I = 0x300
//   202: 6008  V0 = 8      204: 6105  V1 = 5
//   206: D013  draw A at (8,5)                     -> VF=0, saved to V5
//   20A: 623C  V2 = 60     20C: 631E  V3 = 30
//   20E: D233  draw A at (60,30): clips R + bottom -> VF=0, saved to V6
//   212: D013  draw A at (8,5) again: full erase   -> VF=1, saved to V7
//   216: 00E0  clear                       <- checkpoint 1 sampled before this
//   218: 6444  V4 = 68     21A: 6900  V9 = 0
//   21C: D491  draw 1 row at (68 mod 64 = 4, 0)    -> VF=0, saved to V8
//   220: 1220  halt                        <- checkpoint 2 (final state)
module tb_display;
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

    // Watchdog: only bites if the CPU wedges and $finish never runs.
    initial begin
        #100000;
        $display("DISPLAY FAIL: watchdog timeout (CPU wedged?)");
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
        $dumpfile("tb_display.vcd");
        $dumpvars(0, tb_display);
        errors  = 0;
        buttons = '0;

        put(12'h200, 16'hA300);
        put(12'h202, 16'h6008);
        put(12'h204, 16'h6105);
        put(12'h206, 16'hD013);
        put(12'h208, 16'h85F0);  // V5 = VF
        put(12'h20A, 16'h623C);
        put(12'h20C, 16'h631E);
        put(12'h20E, 16'hD233);
        put(12'h210, 16'h86F0);  // V6 = VF
        put(12'h212, 16'hD013);
        put(12'h214, 16'h87F0);  // V7 = VF
        put(12'h216, 16'h00E0);
        put(12'h218, 16'h6444);
        put(12'h21A, 16'h6900);
        put(12'h21C, 16'hD491);
        put(12'h21E, 16'h88F0);  // V8 = VF
        put(12'h220, 16'h1220);

        // Sprite A: open box.
        dut.u_ram.memory[12'h300] = 8'hFF;
        dut.u_ram.memory[12'h301] = 8'h81;
        dut.u_ram.memory[12'h302] = 8'hFF;

        rst = 1'b1;
        repeat (2) @(negedge clk);
        rst = 1'b0;

        // Checkpoint 1: PC has advanced past 0x214, so both (8,5) draws and
        // the clipped corner draw are committed, and 00E0 hasn't run yet.
        wait (dut.PC == 12'h216);
        @(negedge clk);
        check("erased row 5", dut.fb[5], 64'd0);   // XOR twice = gone
        check("erased row 6", dut.fb[6], 64'd0);
        check("erased row 7", dut.fb[7], 64'd0);
        // At x=60 only the left 4 sprite bits fit; at y=30 only 2 of 3 rows.
        check("clipped row 30", dut.fb[30], 64'h0000_0000_0000_000F);
        check("clipped row 31", dut.fb[31], 64'h0000_0000_0000_0008);

        // Checkpoint 2: after clear + the wrapped draw.
        wait (dut.PC == 12'h220);
        @(negedge clk);
        check("wrap row 0", dut.fb[0], 64'h0FF0_0000_0000_0000);
        begin
            logic [63:0] acc;
            acc = 64'd0;
            for (int i = 1; i < 32; i++)
                acc |= dut.fb[i];
            check("00E0 cleared rows 1-31", acc, 64'd0);
        end
        check("draw    VF (V5)", 64'(dut.V[5]), 64'd0);
        check("clipped VF (V6)", 64'(dut.V[6]), 64'd0);
        check("erase   VF (V7)", 64'(dut.V[7]), 64'd1);
        check("wrap    VF (V8)", 64'(dut.V[8]), 64'd0);

        if (errors == 0)
            $display("DISPLAY PASS: draw/erase/collision/clip/wrap/clear all correct");
        else
            $display("DISPLAY FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
