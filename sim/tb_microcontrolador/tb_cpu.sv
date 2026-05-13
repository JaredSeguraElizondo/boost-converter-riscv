`timescale 1ns / 1ps

module tb_cpu;

    logic clk;
    logic reset;
    logic [31:0] WB_Result_Out;
    logic [31:0] PC_Out;

    cpu uut (
        .clk(clk),
        .reset(reset),
        .WB_Result_Out(WB_Result_Out),
        .PC_Out(PC_Out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("cpu_multiciclo_tb.vcd");
        $dumpvars(0, tb_cpu);

        reset = 1;
        $display("Iniciando simulacion...");

        #20;
        reset = 0;
        $display("Reset liberado. CPU corriendo.");

        #500; 

        $display("Simulacion finalizada.");
        $stop;
    end

    always @(negedge clk) begin
        if (!reset) begin
            $display("Time: %0t | PC: %h | WB Result: %h", 
                     $time, PC_Out, WB_Result_Out);
        end
    end

endmodule