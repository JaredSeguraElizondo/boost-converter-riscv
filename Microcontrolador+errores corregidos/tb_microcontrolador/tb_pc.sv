`timescale 1ns/1ps

module tb_pc();
    parameter N = 32;

    logic clk;
    logic reset;
    logic StallF;
    logic [N-1:0] pc_in;
    logic [N-1:0] pc_out;

    pc #(.N(N)) uut (
        .clk(clk),
        .reset(reset),
        .StallF(StallF),
        .pc_in(pc_in),
        .pc_out(pc_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("pc_tb.vcd");
        $dumpvars(0, tb_pc);

        reset = 1;
        StallF = 0;
        pc_in = '0;

        repeat (2) @(posedge clk);
        reset = 0;
        $display("%0t: Reset desactivado", $time);

        pc_in = 32'h00000010;
        StallF = 0;
        @(posedge clk);
        #1;
        $display("%0t: pc_in=0x%08h, pc_out=0x%08h (esperado igual)", $time, pc_in, pc_out);
        if (pc_out !== pc_in) $error("ERROR: pc_out no siguio a pc_in cuando StallF=0");

        pc_in = 32'h00000020;
        StallF = 1;
        @(posedge clk);
        #1;
        $display("%0t: Stall activo, pc_in=0x%08h, pc_out=0x%08h (esperado sin cambio)", $time, pc_in, pc_out);
        if (pc_out === 32'h00000020) $error("ERROR: pc_out cambió durante StallF=1");

        StallF = 0;
        @(posedge clk);
        #1;
        $display("%0t: Stall liberado, pc_in=0x%08h, pc_out=0x%08h (esperado igual)", $time, pc_in, pc_out);
        if (pc_out !== pc_in) $error("ERROR: pc_out no actualizó después de liberar StallF");

        #3;
        reset = 1; 
        @(posedge clk);
        #1;
        $display("%0t: Reset activado, pc_out=0x%08h (esperado 0)", $time, pc_out);
        if (pc_out !== '0) $error("ERROR: pc_out no se puso a 0 tras reset");

        #5;
        $display("Simulación finalizada correctamente.");
        $finish;
    end

endmodule