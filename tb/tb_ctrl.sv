// Control-flow testbench for chip8_cpu (M4). Exercises every branch opcode in
// BOTH directions (taken and not-taken), nested subroutine call/return, and the
// V0-relative jump. Run with: make ctrl
//
// Convention: V1..V9/VD are "markers", explicitly zeroed up front. Each control
// construct either sets its marker to 1 (expected path) or lets a skipped/
// jumped-over instruction poison it with 0xAA. A poisoned register pinpoints
// exactly which opcode misbehaved.
//
// Program (big-endian; byte at PC is the opcode's high byte):
//   200-214: V0=5, V1..V9=0, VD=0
//   216: 3006  V0==6? no  -> fall through          21A: 3005  yes -> skip 21C
//   21E: 4006  V0!=6? yes -> skip 220              224: 4005  no  -> fall through
//   22A: 50A0  V0==VA(5)  -> skip 22C              230: 9010  V0!=V1 -> skip 232
//   236: 2300  call sub1; sub1 calls sub2 (nested), both return
//   23A: B23F  jump 0x23F+V0(5) = 0x244; fallthrough poisons V9 and halts at 23E
//   244: 6901  V9=1;  246: 1246 halt
//   sub1 @300: V6=1, call sub2, V7=1 (proves inner return), return
//   sub2 @340: VD=1, return
module tb_ctrl;
    logic        clk;
    logic        rst;
    logic [15:0] buttons;
    int          errors;

    chip8_cpu dut (
        .clk     (clk),
        .rst     (rst),
        .buttons (buttons)
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

    // Write a 16-bit opcode big-endian into the CPU's RAM.
    task automatic put(input logic [11:0] a, input logic [15:0] op);
        dut.u_ram.memory[a]     = op[15:8];
        dut.u_ram.memory[a + 1] = op[7:0];
    endtask

    initial begin
        $dumpfile("tb_ctrl.vcd");
        $dumpvars(0, tb_ctrl);
        errors  = 0;
        buttons = '0;

        put(12'h200, 16'h6005);  // V0 = 5
        put(12'h202, 16'h6100);  // V1..V9, VD = 0
        put(12'h204, 16'h6200);
        put(12'h206, 16'h6300);
        put(12'h208, 16'h6400);
        put(12'h20A, 16'h6500);
        put(12'h20C, 16'h6600);
        put(12'h20E, 16'h6700);
        put(12'h210, 16'h6800);
        put(12'h212, 16'h6900);
        put(12'h214, 16'h6D00);
        put(12'h216, 16'h3006);  // 3xkk not-taken (V0 != 6)
        put(12'h218, 16'h6101);  //   V1 = 1 must execute
        put(12'h21A, 16'h3005);  // 3xkk taken (V0 == 5)
        put(12'h21C, 16'h61AA);  //   SKIPPED (would poison V1)
        put(12'h21E, 16'h4006);  // 4xkk taken (V0 != 6)
        put(12'h220, 16'h62AA);  //   SKIPPED
        put(12'h222, 16'h6201);  //   V2 = 1
        put(12'h224, 16'h4005);  // 4xkk not-taken (V0 == 5)
        put(12'h226, 16'h6301);  //   V3 = 1 must execute
        put(12'h228, 16'h6A05);  // VA = 5
        put(12'h22A, 16'h50A0);  // 5xy0 taken (V0 == VA)
        put(12'h22C, 16'h64AA);  //   SKIPPED
        put(12'h22E, 16'h6401);  //   V4 = 1
        put(12'h230, 16'h9010);  // 9xy0 taken (V0=5 != V1=1)
        put(12'h232, 16'h65AA);  //   SKIPPED
        put(12'h234, 16'h6501);  //   V5 = 1
        put(12'h236, 16'h2300);  // call sub1 (which calls sub2 -> nested)
        put(12'h238, 16'h6801);  //   V8 = 1 (outer return landed here)
        put(12'h23A, 16'hB23F);  // jump 0x23F + V0(5) = 0x244
        put(12'h23C, 16'h69AA);  //   fallthrough = Bnnn broken: poison V9,
        put(12'h23E, 16'h123E);  //   and halt-trap so 0x244 can't repair it
        put(12'h244, 16'h6901);  //   V9 = 1
        put(12'h246, 16'h1246);  // halt (jump-to-self)

        put(12'h300, 16'h6601);  // sub1: V6 = 1
        put(12'h302, 16'h2340);  //   call sub2
        put(12'h304, 16'h6701);  //   V7 = 1 (inner return landed here)
        put(12'h306, 16'h00EE);  //   return to 0x238

        put(12'h340, 16'h6D01);  // sub2: VD = 1
        put(12'h342, 16'h00EE);  //   return to 0x304

        rst = 1'b1;
        repeat (2) @(negedge clk);
        rst = 1'b0;

        repeat (250) @(negedge clk);  // ~33 instrs * 4 cycles, halt holds state

        check("3xkk fallthrough V1", 16'(dut.V[1]),  16'h01);
        check("4xkk skip        V2", 16'(dut.V[2]),  16'h01);
        check("4xkk fallthrough V3", 16'(dut.V[3]),  16'h01);
        check("5xy0 skip        V4", 16'(dut.V[4]),  16'h01);
        check("9xy0 skip        V5", 16'(dut.V[5]),  16'h01);
        check("sub1 entered     V6", 16'(dut.V[6]),  16'h01);
        check("sub2 returned    V7", 16'(dut.V[7]),  16'h01);
        check("sub1 returned    V8", 16'(dut.V[8]),  16'h01);
        check("Bnnn jump        V9", 16'(dut.V[9]),  16'h01);
        check("sub2 entered     VD", 16'(dut.V[13]), 16'h01);
        check("SP back to 0",       16'(dut.SP),     16'h00);
        check("PC (halt)",          16'(dut.PC),     16'h246);

        if (errors == 0)
            $display("CTRL PASS: all branches, calls, and returns correct");
        else
            $display("CTRL FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
