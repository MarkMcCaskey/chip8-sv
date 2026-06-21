// Warm-up testbench. Pure SystemVerilog, run under `verilator --binary --timing`.
// Generates a clock, pulses reset, drives `en`, self-checks a few values,
// and dumps a VCD you can open in a waveform viewer.
//
// This is the pattern every later CHIP-8 testbench will follow:
//   clock gen -> reset -> drive inputs -> sample outputs -> assert -> $finish
//
// Style note: under Verilator -Wall, a variable must not have a declaration
// initializer if it's also written procedurally (PROCASSINIT). So clk/errors
// are declared bare and initialized inside a process.
module tb_counter;
    logic       clk;
    logic       rst;
    logic       en;
    logic [7:0] count;
    int         errors;

    // Device under test
    counter dut (
        .clk   (clk),
        .rst   (rst),
        .en    (en),
        .count (count)
    );

    // Clock generator: single driver, 10-time-unit period.
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Tiny check helper (uses !== so X/Z mismatches are caught too).
    task automatic expect_count(input logic [7:0] exp);
        if (count !== exp) begin
            $error("count=%0d, expected %0d at t=%0t", count, exp, $time);
            errors++;
        end
    endtask

    // Stimulus
    initial begin
        $dumpfile("warmup/counter.vcd");
        $dumpvars(0, tb_counter);

        errors = 0;

        // Hold reset across a couple of edges.
        rst = 1'b1; en = 1'b0;
        repeat (2) @(posedge clk);
        #1 expect_count(8'd0);

        // Release reset and count up 5 times.
        rst = 1'b0; en = 1'b1;
        repeat (5) @(posedge clk);
        #1 expect_count(8'd5);

        // Pause: value must hold.
        en = 1'b0;
        repeat (3) @(posedge clk);
        #1 expect_count(8'd5);

        // Resume for 2 more.
        en = 1'b1;
        repeat (2) @(posedge clk);
        #1 expect_count(8'd7);

        if (errors == 0)
            $display("WARMUP PASS: counter behaves correctly");
        else
            $display("WARMUP FAIL: %0d error(s)", errors);

        $finish;
    end
endmodule
