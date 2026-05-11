module tb_control_unit;

    logic [6:0] op;
    logic [2:0] funct3;
    logic [6:0] funct7;

    logic       RegWriteD;
    logic [1:0] ResultSrcD;
    logic       MemWriteD;
    logic       JumpD;
    logic       BranchD;
    logic [2:0] ALUControlD;
    logic       ALUSrcD;
    logic [1:0] ImmSrcD;

    control_unit dut (
        .op(op),
        .funct3(funct3),
        .funct7(funct7),
        .RegWriteD(RegWriteD),
        .ResultSrcD(ResultSrcD),
        .MemWriteD(MemWriteD),
        .JumpD(JumpD),
        .BranchD(BranchD),
        .ALUControlD(ALUControlD),
        .ALUSrcD(ALUSrcD),
        .ImmSrcD(ImmSrcD)
    );

    initial begin
        op = 7'b0000011; funct3 = 3'b010; funct7 = 7'b0000000; #5;
        $display("LW: RegWriteD=%b ResultSrcD=%b MemWriteD=%b ALUSrcD=%b ALUControlD=%b ImmSrcD=%b",
                 RegWriteD, ResultSrcD, MemWriteD, ALUSrcD, ALUControlD, ImmSrcD);

        op = 7'b0100011; funct3 = 3'b010; funct7 = 7'b0000000; #5;
        $display("SW: RegWriteD=%b ResultSrcD=%b MemWriteD=%b ALUSrcD=%b ALUControlD=%b ImmSrcD=%b",
                 RegWriteD, ResultSrcD, MemWriteD, ALUSrcD, ALUControlD, ImmSrcD);

        op = 7'b0010011; funct3 = 3'b000; funct7 = 7'b0000000; #5;
        $display("ADDI: RegWriteD=%b ALUSrcD=%b ALUControlD=%b ImmSrcD=%b",
                 RegWriteD, ALUSrcD, ALUControlD, ImmSrcD);

        op = 7'b0010011; funct3 = 3'b111; funct7 = 7'b0000000; #5;
        $display("ANDI: ALUControlD=%b", ALUControlD);

        op = 7'b0010011; funct3 = 3'b110; funct7 = 7'b0000000; #5;
        $display("ORI: ALUControlD=%b", ALUControlD);

        op = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0000000; #5;
        $display("ADD: RegWriteD=%b ALUSrcD=%b ALUControlD=%b", RegWriteD, ALUSrcD, ALUControlD);

        op = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0100000; #5;
        $display("SUB: ALUControlD=%b", ALUControlD);

        op = 7'b0110011; funct3 = 3'b001; funct7 = 7'b0000000; #5;
        $display("SLL: ALUControlD=%b", ALUControlD);

        op = 7'b0110011; funct3 = 3'b101; funct7 = 7'b0000000; #5;
        $display("SRL: ALUControlD=%b", ALUControlD);

        op = 7'b0110011; funct3 = 3'b101; funct7 = 7'b0100000; #5;
        $display("SRA: ALUControlD=%b", ALUControlD);

        op = 7'b0110011; funct3 = 3'b010; funct7 = 7'b0000000; #5;
        $display("SLT: ALUControlD=%b", ALUControlD);

        op = 7'b0110011; funct3 = 3'b011; funct7 = 7'b0000000; #5;
        $display("SLTU: ALUControlD=%b", ALUControlD);

        op = 7'b1100011; funct3 = 3'b000; funct7 = 7'b0000000; #5;
        $display("BEQ: BranchD=%b ALUControlD=%b ImmSrcD=%b", BranchD, ALUControlD, ImmSrcD);

        op = 7'b1100011; funct3 = 3'b100; funct7 = 7'b0000000; #5;
        $display("BLT: BranchD=%b ALUControlD=%b ImmSrcD=%b", BranchD, ALUControlD, ImmSrcD);

        op = 7'b1101111; funct3 = 3'b000; funct7 = 7'b0000000; #5;
        $display("JAL: JumpD=%b RegWriteD=%b ResultSrcD=%b ImmSrcD=%b", JumpD, RegWriteD, ResultSrcD, ImmSrcD);

        op = 7'b1100111; funct3 = 3'b000; funct7 = 7'b0000000; #5;
        $display("JALR: JumpD=%b RegWriteD=%b ResultSrcD=%b ALUSrcD=%b ALUControlD=%b ImmSrcD=%b",
                 JumpD, RegWriteD, ResultSrcD, ALUSrcD, ALUControlD, ImmSrcD);

        op = 7'b0000000; funct3 = 3'b000; funct7 = 7'b0000000; #5;
        $display("NOP: RegWriteD=%b", RegWriteD);

        $display("=== Fin del testbench CONTROL_UNIT ===");
        $finish;
    end

    initial begin
        $dumpfile("tb_control_unit_waves.vcd");
        $dumpvars(0, tb_control_unit);
    end

endmodule
