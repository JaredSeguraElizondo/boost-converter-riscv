

`timescale 1ns / 1ps

module tb_reg_bank_proyecto3;

    logic        clk;
    logic        rst;   // [FIX] nuevo
    logic        WE3;
    logic [4:0]  A1, A2, A3;
    logic [31:0] WD3;
    logic [31:0] RD1, RD2;

    Reg_Bank uut (
        .clk (clk),
        .rst (rst),   // [FIX]
        .WE3 (WE3),
        .A1  (A1),
        .A2  (A2),
        .A3  (A3),
        .WD3 (WD3),
        .RD1 (RD1),
        .RD2 (RD2)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task check(input string tag, input logic [31:0] got, input logic [31:0] exp);
        if (got === exp) $display("PASS  %s = 0x%08h", tag, got);
        else             $display("FAIL  %s = 0x%08h (esperado 0x%08h)", tag, got, exp);
    endtask

    initial begin
        $dumpfile("tb_reg_bank_proyecto3.vcd");
        $dumpvars(0, tb_reg_bank_proyecto3);
        $display("=== Testbench Reg_Bank (Proyecto 3) ===");

        // ── Reset ──
        rst=1; WE3=0; A1=0; A2=0; A3=0; WD3=0;
        @(posedge clk); @(posedge clk);
        rst=0;

        // ── Escritura en registros usados por el assembly ──
        // x20 = 0x00010000 (base perifericos)
        WE3=1; A3=5'd20; WD3=32'h00010000; @(posedge clk);
        // x15 = 0x00002000 (base RAM)
        A3=5'd15; WD3=32'h00002000; @(posedge clk);
        // x9  = 100 (max duty)
        A3=5'd9;  WD3=32'd100; @(posedge clk);
        // x1  = 3277 (Vref)
        A3=5'd1;  WD3=32'd3277; @(posedge clk);
        // x31 = return address (usado por jal x31, uart_send_char)
        A3=5'd31; WD3=32'h000001A0; @(posedge clk);
        WE3=0;

        // ── Lecturas ──
        A1=5'd20; A2=5'd15; #2;
        check("x20 (periph_base)", RD1, 32'h00010000);
        check("x15 (ram_base)",    RD2, 32'h00002000);

        A1=5'd9;  A2=5'd1;  #2;
        check("x9  (max_duty=100)", RD1, 32'd100);
        check("x1  (Vref=3277)",    RD2, 32'd3277);

        A1=5'd31; A2=5'd0;  #2;
        check("x31 (ra)",  RD1, 32'h000001A0);
        check("x0  (zero)", RD2, 32'h00000000);   // x0 siempre 0

        // ── Intentar escribir x0 (debe seguir siendo 0) ──
        WE3=1; A3=5'd0; WD3=32'hDEADBEEF; @(posedge clk);
        WE3=0;
        A1=5'd0; #2;
        check("x0 after write (debe ser 0)", RD1, 32'h00000000);

        // ── Reset limpia registros ──
        WE3=1; A3=5'd5; WD3=32'hCAFEBABE; @(posedge clk);
        WE3=0;
        rst=1; @(posedge clk); rst=0;
        A1=5'd5; #2;
        check("x5 post-reset (debe ser 0)", RD1, 32'h00000000);

        $display("=== Fin testbench Reg_Bank ===");
        $finish;
    end

endmodule