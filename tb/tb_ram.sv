// Testbench for `ram` -- 4 KB byte memory with synchronous (registered) read.
// Run with:  make ram
//
// Contract under test:
//   * a byte written to an address can be read back
//   * reads have ONE cycle of latency (present address -> data valid next clock)
//   * distinct addresses don't alias; an overwrite replaces the value
//
// All reads are done with writeEnabled=0, so this test is valid whether your RAM
// reads every cycle or only when not writing.
//
// Convention: we DRIVE inputs on negedge and SAMPLE outputs on negedge, so the
// RAM's posedge always sees stable inputs. Changing inputs on the same edge the
// DUT samples causes write-enable races (the write can be silently dropped).
//
// Assumes this port list (your draft):
//   ram(clk, address[11:0], writeData[7:0], writeEnabled, readData[7:0])
// If you rename a port or change the address width, update the dut hookup below.
module tb_ram;
    logic        clk;
    logic [11:0] address;
    logic [7:0]  writeData;
    logic        writeEnabled;
    logic [7:0]  readData;
    int          errors;

    ram dut (
        .clk          (clk),
        .address      (address),
        .writeData    (writeData),
        .writeEnabled (writeEnabled),
        .readData     (readData)
    );

    // Clock: single driver, 10-time-unit period.
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Write one byte; it commits on the posedge while inputs are held stable.
    task automatic write_byte(input logic [11:0] a, input logic [7:0] d);
        @(negedge clk);
        address      = a;
        writeData    = d;
        writeEnabled = 1'b1;
        @(posedge clk);          // memory[a] <= d commits here
        @(negedge clk);
        writeEnabled = 1'b0;
    endtask

    // Present an address; one posedge later the registered read is valid.
    task automatic read_check(input logic [11:0] a, input logic [7:0] exp);
        @(negedge clk);
        address      = a;
        writeEnabled = 1'b0;
        @(posedge clk);          // readData <= memory[a] here (1-cycle latency)
        @(negedge clk);          // posedge has propagated; safe to sample
        if (readData !== exp) begin
            $error("mem[0x%03h] read 0x%02h, expected 0x%02h (t=%0t)",
                   a, readData, exp, $time);
            errors++;
        end
    endtask

    initial begin
        $dumpfile("tb_ram.vcd");
        $dumpvars(0, tb_ram);

        errors       = 0;
        address      = '0;
        writeData    = '0;
        writeEnabled = 1'b0;

        // Write a spread of addresses, including both extremes.
        write_byte(12'h000, 8'h01);   // bottom of memory
        write_byte(12'h200, 8'hAB);   // where CHIP-8 programs start
        write_byte(12'h201, 8'hCD);   // adjacent byte (2nd half of an opcode)
        write_byte(12'hFFF, 8'h42);   // top of memory

        // Read them all back.
        read_check(12'h000, 8'h01);
        read_check(12'h200, 8'hAB);
        read_check(12'h201, 8'hCD);
        read_check(12'hFFF, 8'h42);

        // Overwrite must replace; the neighbor must be untouched.
        write_byte(12'h200, 8'h99);
        read_check(12'h200, 8'h99);
        read_check(12'h201, 8'hCD);

        if (errors == 0)
            $display("RAM PASS: all reads matched");
        else
            $display("RAM FAIL: %0d error(s)", errors);

        $finish;
    end
endmodule
