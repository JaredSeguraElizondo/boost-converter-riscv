module tb_register_ex_mem;

    logic clk;
    logic reset;

    logic [31:0] ALUResultE, WriteDataE, PCPlus4E;
    logic [4:0]  RdE;
    logic        RegWriteE, MemWriteE;
    logic [1:0]  ResultSrcE;

    logic [31:0] ALUResultM, WriteDataM, PCPlus4M;
    logic [4:0]  RdM;
    logic        RegWriteM, MemWriteM;
    logic [1:0]  ResultSrcM;

    // Instancia del DUT
    register_ex_mem dut (
        .clk(clk),
        .reset(reset),
        .ALUResultE(ALUResultE),
        .WriteDataE(WriteDataE),
        .PCPlus4E(PCPlus4E),
        .RdE(RdE),
        .RegWriteE(RegWriteE),
        .ResultSrcE(ResultSrcE),
        .MemWriteE(MemWriteE),

        .ALUResultM(ALUResultM),
        .WriteDataM(WriteDataM),
        .PCPlus4M(PCPlus4M),
        .RdM(RdM),
        .RegWriteM(RegWriteM),
        .ResultSrcM(ResultSrcM),
        .MemWriteM(MemWriteM)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin

        reset = 1;
        ALUResultE = 32'h00000000;
        WriteDataE = 32'h00000000;
        PCPlus4E   = 32'h00000000;
        RdE        = 5'd0;
        RegWriteE  = 0;
        ResultSrcE = 2'b00;
        MemWriteE  = 0;

        #12;
        reset = 0;

        #10;
        ALUResultE = 32'h11112222;
        WriteDataE = 32'h33334444;
        PCPlus4E   = 32'h55556666;
        RdE        = 5'd15;
        RegWriteE  = 1;
        ResultSrcE = 2'b01;
        MemWriteE  = 1;

        #10;
        ALUResultE = 32'hAAAA0001;
        WriteDataE = 32'hBBBB0002;
        PCPlus4E   = 32'hCCCC0003;
        RdE        = 5'd20;
        RegWriteE  = 0;
        ResultSrcE = 2'b10;
        MemWriteE  = 0;

        #10;
        reset = 1;
        #10;
        reset = 0;

        #10;
        ALUResultE = 32'hDEADBEEF;
        WriteDataE = 32'hCAFEBABE;
        PCPlus4E   = 32'hBAADF00D;
        RdE        = 5'd31;
        RegWriteE  = 1;
        ResultSrcE = 2'b11;
        MemWriteE  = 1;

        #10;
        $finish;
    end

    initial begin
        $monitor("T=%0t | reset=%b | ALUResultE=%h | WriteDataE=%h | PCPlus4E=%h | RdE=%d | RegWriteE=%b | ResultSrcE=%b | MemWriteE=%b || ALUResultM=%h | WriteDataM=%h | PCPlus4M=%h | RdM=%d | RegWriteM=%b | ResultSrcM=%b | MemWriteM=%b",
            $time, reset, ALUResultE, WriteDataE, PCPlus4E, RdE, RegWriteE, ResultSrcE, MemWriteE,
            ALUResultM, WriteDataM, PCPlus4M, RdM, RegWriteM, ResultSrcM, MemWriteM);
    end

    initial begin
        $dumpfile("tb_register_ex_mem_waves.vcd");
        $dumpvars(0, tb_register_ex_mem);
    end

endmodule
