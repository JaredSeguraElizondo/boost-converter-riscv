
`timescale 1ns / 1ps

module tb_hazard_unit;

    logic [4:0] Rs1D, Rs2D;
    logic [4:0] RdE;
    logic [1:0] ResultSrcE;
    logic       PCSrcE;

    logic       StallF, StallD, FlushD, FlushE;

    hazard_unit uut (
        .Rs1D(Rs1D),
        .Rs2D(Rs2D),
        .RdE(RdE),
        .ResultSrcE(ResultSrcE),
        .PCSrcE(PCSrcE),
        .StallF(StallF),
        .StallD(StallD),
        .FlushD(FlushD),
        .FlushE(FlushE)
    );

    initial begin
        $dumpfile("sim/vcd/tb_hazard_unit.vcd");
        $dumpvars(0, tb_hazard_unit);

        Rs1D = 5'd1; Rs2D = 5'd2; RdE = 5'd3; ResultSrcE = 2'b00; PCSrcE = 0;
        #10;

        Rs1D = 5'd5; Rs2D = 5'd0; RdE = 5'd5; ResultSrcE = 2'b01; PCSrcE = 0;
        #10;

        Rs1D = 5'd0; Rs2D = 5'd8; RdE = 5'd8; ResultSrcE = 2'b01; PCSrcE = 0;
        #10;

        Rs1D = 5'd1; Rs2D = 5'd2; RdE = 5'd0; ResultSrcE = 2'b01; PCSrcE = 0;
        #10;

        Rs1D = 5'd3; Rs2D = 5'd4; RdE = 5'd9; ResultSrcE = 2'b00; PCSrcE = 1;
        #10;

        Rs1D = 5'd9; Rs2D = 5'd4; RdE = 5'd9; ResultSrcE = 2'b01; PCSrcE = 1;
        #10;

        $display("Testbench finalizado.");
        $finish;
    end

endmodule
