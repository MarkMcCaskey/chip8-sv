// Generic ROM runner (M9): loads a real CHIP-8 ROM into RAM at 0x200, runs it
// for a fixed number of cycles, and prints the framebuffer as ASCII art so the
// result can be inspected (the Timendus suite ROMs report pass/fail visually).
//
//   make rom ROM=roms/3-corax+.ch8              # run the opcode test
//   make rom ROM=roms/5-quirks.ch8 SEL=1        # quirks test, CHIP-8 preselected
//
// Plusargs:
//   +ROM=<file>   hex byte stream (one byte per line, from `xxd -p -c1`)
//   +CYCLES=<n>   how long to run (default 300000 = ~78 s of emulated time)
//   +SEL=<n>      if nonzero, poked into RAM[0x1FF] -- the Timendus ROMs read
//                 this byte to skip their menus (e.g. quirks: 1 = CHIP-8)
//   +TRACE        dump tb_rom.vcd (off by default; ROM runs are long)
//
// CYCLES_PER_TICK=64 with 4 cycles/instruction gives 16 instructions per 60 Hz
// frame -- close to a real COSMAC VIP, which the quirks ROM's display-wait and
// timing measurements depend on.
module tb_rom;
    logic        clk;
    logic        rst;
    logic [15:0] buttons;
    // verilator lint_off UNUSEDSIGNAL
    logic        sound_on;
    // verilator lint_on UNUSEDSIGNAL

    chip8_cpu #(.CYCLES_PER_TICK(64)) dut (
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
        string romfile;
        int    cycles;
        int    sel;

        buttons = '0;
        cycles  = 300000;
        sel     = 0;

        if (!$value$plusargs("ROM=%s", romfile)) begin
            $display("ROM FAIL: missing +ROM=<hexfile>");
            $fatal;
        end
        void'($value$plusargs("CYCLES=%d", cycles));
        void'($value$plusargs("SEL=%d", sel));
        if ($test$plusargs("TRACE")) begin
            $dumpfile("tb_rom.vcd");
            $dumpvars(0, tb_rom);
        end

        $readmemh(romfile, dut.u_ram.memory, 'h200);
        if (sel != 0)
            dut.u_ram.memory[12'h1FF] = 8'(sel);

        rst = 1'b1;
        repeat (2) @(negedge clk);
        rst = 1'b0;

        repeat (cycles) @(negedge clk);

        $display("--- framebuffer after %0d cycles (PC=0x%03h) ---", cycles, dut.PC);
        for (int y = 0; y < 32; y++) begin
            for (int x = 0; x < 64; x++) begin
                if (dut.fb[y][63 - x])
                    $write("#");
                else
                    $write(".");
            end
            $write("\n");
        end
        $display("--- end framebuffer ---");
        $finish;
    end
endmodule
