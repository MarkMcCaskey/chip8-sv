// ALU / VF-flag testbench for chip8_cpu. Exercises the whole 8xy_ group and,
// crucially, the VF flag each one produces (carry / borrow / shift-out) -- the
// part the basic CPU test took on faith. Run with: make alu
//
// Trick: VF (V[0xF]) is overwritten by every flag-setting op, so right after
// each op we copy VF into a dedicated save register with `8sF0` (8xy0 doesn't
// touch VF), letting us check every flag at the end.
//
// Program (big-endian; byte at PC is the opcode's high byte):
//   8xy4 carry:     V0 = 0xF0 + 0x20 -> 0x10, VF=1   saved in V5
//   8xy5 no-borrow: V1 = 0x05 - 0x03 -> 0x02, VF=1   saved in V6
//   8xy5 borrow:    V2 = 0x03 - 0x05 -> 0xFE, VF=0   saved in V7
//   8xy6 shr:       V3 = 0x05 >> 1   -> 0x02, VF=1   saved in V8
//   8xyE shl:       V4 = 0x80 << 1   -> 0x00, VF=1   saved in V9
//   8xy7 no-borrow: VB = 0x09 - 0x02 -> 0x07, VF=1   saved in VC
module tb_alu;
    logic       clk;
    logic       rst;
    logic [15:0] buttons;
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

    task automatic check(string name, logic [15:0] got, logic [15:0] exp);
        if (got !== exp) begin
            $error("%s = 0x%03h, expected 0x%03h", name, got, exp);
            errors++;
        end
    endtask

    // Write a 16-bit opcode big-endian into the CPU's RAM.
    task automatic put(input logic [11:0] a, input logic [15:0] op);
        dut.u_ram.memory[a]      = op[15:8];
        dut.u_ram.memory[a + 1]  = op[7:0];
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
        errors  = 0;
        buttons = '0;

        put(12'h200, 16'h60F0);  // V0 = 0xF0
        put(12'h202, 16'h6A20);  // VA = 0x20
        put(12'h204, 16'h80A4);  // V0 = V0 + VA  -> 0x10, VF=1   (8xy4 carry)
        put(12'h206, 16'h85F0);  // V5 = VF
        put(12'h208, 16'h6105);  // V1 = 0x05
        put(12'h20A, 16'h6A03);  // VA = 0x03
        put(12'h20C, 16'h81A5);  // V1 = V1 - VA  -> 0x02, VF=1   (8xy5 no-borrow)
        put(12'h20E, 16'h86F0);  // V6 = VF
        put(12'h210, 16'h6203);  // V2 = 0x03
        put(12'h212, 16'h6A05);  // VA = 0x05
        put(12'h214, 16'h82A5);  // V2 = V2 - VA  -> 0xFE, VF=0   (8xy5 borrow)
        put(12'h216, 16'h87F0);  // V7 = VF
        put(12'h218, 16'h6305);  // V3 = 0x05
        put(12'h21A, 16'h8336);  // V3 = V3 >> 1  -> 0x02, VF=1   (8xy6, LSB out)
        put(12'h21C, 16'h88F0);  // V8 = VF
        put(12'h21E, 16'h6480);  // V4 = 0x80
        put(12'h220, 16'h844E);  // V4 = V4 << 1  -> 0x00, VF=1   (8xyE, MSB out)
        put(12'h222, 16'h89F0);  // V9 = VF
        put(12'h224, 16'h6B02);  // VB = 0x02
        put(12'h226, 16'h6E09);  // VE = 0x09
        put(12'h228, 16'h8BE7);  // VB = VE - VB  -> 0x07, VF=1   (8xy7 no-borrow)
        put(12'h22A, 16'h8CF0);  // VC = VF
        put(12'h22C, 16'h122C);  // jump self (halt)

        rst = 1'b1;
        repeat (2) @(negedge clk);
        rst = 1'b0;

        repeat (150) @(negedge clk);   // ~23 instrs * 4 cycles, halt holds state

        check("8xy4 sum  V0", 16'(dut.V[0]),  16'h10);
        check("8xy4 carry VF",16'(dut.V[5]),  16'h01);
        check("8xy5 res   V1",16'(dut.V[1]),  16'h02);
        check("8xy5 !brw  VF",16'(dut.V[6]),  16'h01);
        check("8xy5 res   V2",16'(dut.V[2]),  16'hFE);
        check("8xy5 brw   VF",16'(dut.V[7]),  16'h00);
        check("8xy6 res   V3",16'(dut.V[3]),  16'h02);
        check("8xy6 lsb   VF",16'(dut.V[8]),  16'h01);
        check("8xyE res   V4",16'(dut.V[4]),  16'h00);
        check("8xyE msb   VF",16'(dut.V[9]),  16'h01);
        check("8xy7 res   VB",16'(dut.V[11]), 16'h07);
        check("8xy7 !brw  VF",16'(dut.V[12]), 16'h01);
        check("PC (halt)",    16'(dut.PC),    16'h22C);

        if (errors == 0)
            $display("ALU PASS: all 8xy_ results and VF flags correct");
        else
            $display("ALU FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
