
`timescale 1ns / 1ps

module tb_forwarding_unit;

    logic [4:0] Rs1E, Rs2E;
    logic [4:0] RdM, RdW;
    logic       RegWriteM, RegWriteW;

    logic [1:0] ForwardAE, ForwardBE;

    forwarding_unit uut (
        .Rs1E(Rs1E), .Rs2E(Rs2E),
        .RdM(RdM), .RdW(RdW),
        .RegWriteM(RegWriteM), .RegWriteW(RegWriteW),
        .ForwardAE(ForwardAE), .ForwardBE(ForwardBE)
    );

    initial begin
        $dumpfile("sim/vcd/tb_forwarding_unit.vcd");
        $dumpvars(0, tb_forwarding_unit);

        Rs1E = 5'd1; Rs2E = 5'd2;
        RdM  = 5'd0; RdW  = 5'd0;
        RegWriteM = 0; RegWriteW = 0;
        #10;

        Rs1E = 5'd5; Rs2E = 5'd2;
        RdM  = 5'd5; RdW  = 5'd0;
        RegWriteM = 1; RegWriteW = 0;
        #10;

        Rs1E = 5'd1; Rs2E = 5'd6;
        RdM  = 5'd6; RdW  = 5'd0;
        RegWriteM = 1; RegWriteW = 0;
        #10;

        Rs1E = 5'd3; Rs2E = 5'd2;
        RdM  = 5'd0; RdW  = 5'd3;
        RegWriteM = 0; RegWriteW = 1;
        #10;

        Rs1E = 5'd1; Rs2E = 5'd4;
        RdM  = 5'd0; RdW  = 5'd4;
        RegWriteM = 0; RegWriteW = 1;
        #10;

        Rs1E = 5'd7; Rs2E = 5'd8;
        RdM  = 5'd7; RdW  = 5'd7;
        RegWriteM = 1; RegWriteW = 1;
        #10;

        $display("Testbench finalizado.");
        $finish;
    end

endmodule
