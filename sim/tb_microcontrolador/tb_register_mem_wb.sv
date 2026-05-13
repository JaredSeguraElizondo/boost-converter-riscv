module tb_register_mem_wb;

    logic clk;
    logic reset;

    logic        RegWriteM;
    logic [1:0]  ResultSrcM;
    logic [31:0] ALUResultM, RD, PCPlus4M;
    logic [4:0]  RdM;

    logic        RegWriteW;
    logic [1:0]  ResultSrcW;
    logic [31:0] ALUResultW, ReadDataW, PCPlus4W;
    logic [4:0]  RdW;

    register_mem_wb dut (
        .clk(clk),
        .reset(reset),
        .RegWriteM(RegWriteM),
        .ResultSrcM(ResultSrcM),
        .ALUResultM(ALUResultM),
        .RD(RD),
        .PCPlus4M(PCPlus4M),
        .RdM(RdM),
        .RegWriteW(RegWriteW),
        .ResultSrcW(ResultSrcW),
        .ALUResultW(ALUResultW),
        .ReadDataW(ReadDataW),
        .PCPlus4W(PCPlus4W),
        .RdW(RdW)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        reset = 1;
        RegWriteM = 0;
        ResultSrcM = 2'b00;
        ALUResultM = 32'h00000000;
        RD = 32'h00000000;
        PCPlus4M = 32'h00000000;
        RdM = 5'd0;

        #12;
        reset = 0;

        #10;
        RegWriteM = 1;
        ResultSrcM = 2'b01;
        ALUResultM = 32'h12345678;
        RD = 32'h87654321;
        PCPlus4M = 32'hABCDEF12;
        RdM = 5'd10;

        #10;
        RegWriteM = 0;
        ResultSrcM = 2'b10;
        ALUResultM = 32'hDEADBEEF;
        RD = 32'hCAFEBABE;
        PCPlus4M = 32'h0000BEEF;
        RdM = 5'd15;

        #10;
        reset = 1;
        #10;
        reset = 0;

        #10;
        RegWriteM = 1;
        ResultSrcM = 2'b11;
        ALUResultM = 32'hF0F0F0F0;
        RD = 32'h0F0F0F0F;
        PCPlus4M = 32'hAAAA5555;
        RdM = 5'd31;

        #10;
        $finish;
    end

    initial begin
        $monitor("T=%0t | reset=%b | RegWriteM=%b | ResultSrcM=%b | ALUResultM=%h | RD=%h | PCPlus4M=%h | RdM=%d || RegWriteW=%b | ResultSrcW=%b | ALUResultW=%h | ReadDataW=%h | PCPlus4W=%h | RdW=%d",
            $time, reset, RegWriteM, ResultSrcM, ALUResultM, RD, PCPlus4M, RdM,
            RegWriteW, ResultSrcW, ALUResultW, ReadDataW, PCPlus4W, RdW);
    end

    initial begin
        $dumpfile("tb_register_mem_wb_waves.vcd");
        $dumpvars(0, tb_register_mem_wb);
    end

endmodule
