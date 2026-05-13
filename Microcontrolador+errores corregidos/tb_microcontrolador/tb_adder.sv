`timescale 1ns/1ps

module adder_tb;

    parameter N = 32;

    logic [N-1:0] in1;
    logic [N-1:0] in2;
    logic [N-1:0] out;

    adder #(N) dut (
        .in1(in1),
        .in2(in2),
        .out(out)
    );

    initial begin
        $dumpfile("tb_adder_waves.vcd");
        $dumpvars(0, tb_adder);
    end

    initial begin
        in1 = 32'h0000_0001;
        in2 = 32'h0000_0002;
        #1; 
        $display("Prueba 1: %h + %h = %h", in1, in2, out);

        in1 = 32'hFFFF_FFFF;
        in2 = 32'h0000_0001;
        #1;
        $display("Prueba 2: %h + %h = %h", in1, in2, out);

        in1 = 32'h1234_5678;
        in2 = 32'h8765_4321;
        #1;
        $display("Prueba 3: %h + %h = %h", in1, in2, out);

        in1 = 0;
        in2 = 0;
        #1;
        $display("Prueba 4: %h + %h = %h", in1, in2, out);

        in1 = -5;
        in2 = 8;
        #1;
        $display("Prueba 5: %0d + %0d = %0d", in1, in2, out);

        $finish;
    end

endmodule
