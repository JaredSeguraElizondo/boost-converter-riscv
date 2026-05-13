`timescale 1ns/1ps

module tb_mux31();

    logic [31:0] a, b, c;
    logic [1:0] sel;
    logic [31:0] f;

    mux31 uut (
        .a(a),
        .b(b),
        .c(c),
        .sel(sel),
        .f(f)
    );

    initial begin
        $dumpfile("mux31_tb.vcd");
        $dumpvars(0, tb_mux31);

        a = 32'hAAAAAAAA;
        b = 32'h55555555;
        c = 32'hDEADBEEF;

        sel = 2'b00;
        #1;
        $display("%0t: sel=%b -> f=0x%08h (esperado 0x%08h)", $time, sel, f, a);
        if (f !== a) $error("Fallo: sel=00, f debe ser a (0x%08h), pero es 0x%08h", a, f);

        sel = 2'b01;
        #1;
        $display("%0t: sel=%b -> f=0x%08h (esperado 0x%08h)", $time, sel, f, b);
        if (f !== b) $error("Fallo: sel=01, f debe ser b (0x%08h), pero es 0x%08h", b, f);

        sel = 2'b10;
        #1;
        $display("%0t: sel=%b -> f=0x%08h (esperado 0x%08h)", $time, sel, f, c);
        if (f !== c) $error("Fallo: sel=10, f debe ser c (0x%08h), pero es 0x%08h", c, f);

        sel = 2'b11;
        #1;
        $display("%0t: sel=%b -> f=0x%08h (esperado 0x%08h)", $time, sel, f, 32'h0);
        if (f !== 32'h0) $error("Fallo: sel=11, f debe ser 0, pero es 0x%08h", f);

        $display("Pruebas completadas.");
        #5;
        $finish;
    end

endmodule
