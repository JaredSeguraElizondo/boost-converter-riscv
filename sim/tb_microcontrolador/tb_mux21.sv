module tb_mux21;
    localparam N = 16;
    localparam NUM_TESTS = 50;

    logic [N-1:0] a, b;
    logic sel;
    logic [N-1:0] f;

    mux21 #(.N(N)) dut (
        .a(a),
        .b(b),
        .sel(sel),
        .f(f)
    );

    initial begin
        $dumpfile("mux21_waves.vcd");
        $dumpvars(0, tb_mux21);
    end

    int i;
    logic [N-1:0] expected_f;

    initial begin
        $display("Starting 2:1 MUX Testbench with %0d testcases...", NUM_TESTS);

        for (i = 0; i < NUM_TESTS; i++) begin
            a   = $urandom;
            b   = $urandom;
            sel = $urandom_range(0, 1);

            #1;

            expected_f = sel ? b : a;

            if (f !== expected_f) begin
                $error("Test %0d FAILED: a=0x%h, b=0x%h, sel=%b | f=0x%h (expected 0x%h)", 
                        i, a, b, sel, f, expected_f);
            end else begin
                $display("Test %0d PASSED: a=0x%h, b=0x%h, sel=%b | f=0x%h", 
                        i, a, b, sel, f);
            end

            #1;
        end

        $display("All testcases completed.");
        $finish;
    end
endmodule
