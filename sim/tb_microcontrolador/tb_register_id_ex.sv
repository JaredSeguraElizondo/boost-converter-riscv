

`timescale 1ns / 1ps

module tb_register_id_ex_proyecto3;

    logic clk;
    logic reset;
    logic FlushE;

    // ── Entradas ID ──
    logic [31:0] PCD, PCPlus4D, RD1D, RD2D, ImmExtD;
    logic [4:0]  Rs1D, Rs2D, RdD;
    logic [2:0]  funct3D;   // [FIX1]
    logic [6:0]  funct7D;   // [FIX1]
    logic        RegWriteD, MemWriteD, JumpD, BranchD, ALUSrcD;
    logic [1:0]  ResultSrcD;
    logic [2:0]  ALUControlD;
    logic        SubD;      // [FIX5]

    // ── Salidas EX ──
    logic [31:0] PCE, PCPlus4E, RD1E, RD2E, ImmExtE;
    logic [4:0]  Rs1E, Rs2E, RdE;
    logic [2:0]  funct3E;   // [FIX1]
    logic [6:0]  funct7E;   // [FIX1]
    logic        RegWriteE, MemWriteE, JumpE, BranchE, ALUSrcE;
    logic [1:0]  ResultSrcE;
    logic [2:0]  ALUControlE;
    logic        SubE;      // [FIX5]

    register_id_ex dut (
        .clk        (clk),
        .reset      (reset),
        .FlushE     (FlushE),
        .PCD        (PCD),      .PCPlus4D  (PCPlus4D),
        .RD1D       (RD1D),     .RD2D      (RD2D),
        .ImmExtD    (ImmExtD),
        .Rs1D       (Rs1D),     .Rs2D      (Rs2D),    .RdD       (RdD),
        .funct3D    (funct3D),  .funct7D   (funct7D),  // [FIX1]
        .RegWriteD  (RegWriteD),.ResultSrcD(ResultSrcD),
        .MemWriteD  (MemWriteD),.JumpD     (JumpD),
        .BranchD    (BranchD),  .ALUControlD(ALUControlD),
        .ALUSrcD    (ALUSrcD),  .SubD      (SubD),     // [FIX5]
        .PCE        (PCE),      .PCPlus4E  (PCPlus4E),
        .RD1E       (RD1E),     .RD2E      (RD2E),
        .ImmExtE    (ImmExtE),
        .Rs1E       (Rs1E),     .Rs2E      (Rs2E),     .RdE       (RdE),
        .funct3E    (funct3E),  .funct7E   (funct7E),  // [FIX1]
        .RegWriteE  (RegWriteE),.ResultSrcE(ResultSrcE),
        .MemWriteE  (MemWriteE),.JumpE     (JumpE),
        .BranchE    (BranchE),  .ALUControlE(ALUControlE),
        .ALUSrcE    (ALUSrcE),  .SubE      (SubE)      // [FIX5]
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_register_id_ex_proyecto3.vcd");
        $dumpvars(0, tb_register_id_ex_proyecto3);
    end

    task check_propagation(input string tag);
        @(posedge clk); #1;
        $display("--- %s propagado ---", tag);
        $display("  funct3: %b → %b %s", funct3D, funct3E,
                 (funct3E===funct3D) ? "OK" : "FAIL");
        $display("  funct7: %b → %b %s", funct7D, funct7E,
                 (funct7E===funct7D) ? "OK" : "FAIL");
        $display("  SubD:   %b → SubE:%b %s", SubD, SubE,
                 (SubE===SubD) ? "OK" : "FAIL");
    endtask

    initial begin
        reset=1; FlushE=0;
        PCD=32'h0; PCPlus4D=32'h4; RD1D=32'h0; RD2D=32'h0; ImmExtD=32'h0;
        Rs1D=5'd0; Rs2D=5'd0; RdD=5'd0;
        funct3D=3'b000; funct7D=7'b0; SubD=0;
        RegWriteD=0; ResultSrcD=2'b00; MemWriteD=0;
        JumpD=0; BranchD=0; ALUControlD=3'b000; ALUSrcD=0;

        #12; reset=0;

        // ── Caso 1: SUB (sub x2, x1, x7) — funct7[5]=1, Sub=1 ──
        PCD=32'hC; PCPlus4D=32'h10;
        RD1D=32'h0CCD; RD2D=32'h0800;
        ImmExtD=32'h0;
        Rs1D=5'd1; Rs2D=5'd7; RdD=5'd2;
        funct3D=3'b000; funct7D=7'b0100000; SubD=1;
        RegWriteD=1; ResultSrcD=2'b00; MemWriteD=0;
        JumpD=0; BranchD=0; ALUControlD=3'b000; ALUSrcD=0;
        check_propagation("SUB: funct7=0100000, Sub=1");

        // ── Caso 2: SRAI — funct7[5]=1, Sub=0 (no es resta) ──
        PCD=32'h10; PCPlus4D=32'h14;
        RD1D=32'h19000; RD2D=32'h0;
        ImmExtD=32'h0000000A;  // shamt=10
        Rs1D=5'd4; Rs2D=5'd0; RdD=5'd6;
        funct3D=3'b101; funct7D=7'b0100000; SubD=0;  // Sub=0 para SRAI
        RegWriteD=1; ResultSrcD=2'b00; MemWriteD=0;
        JumpD=0; BranchD=0; ALUControlD=3'b101; ALUSrcD=1;
        check_propagation("SRAI: funct7=0100000, Sub=0 (no resta)");

        // ── Caso 3: BGE — funct3=101 ──
        PCD=32'h14; PCPlus4D=32'h18;
        RD1D=32'h19000; RD2D=32'h0;
        ImmExtD=32'hFFFFFFF8;
        Rs1D=5'd4; Rs2D=5'd0; RdD=5'd0;
        funct3D=3'b101; funct7D=7'b0; SubD=0;
        RegWriteD=0; ResultSrcD=2'b00; MemWriteD=0;
        JumpD=0; BranchD=1; ALUControlD=3'b000; ALUSrcD=0;
        check_propagation("BGE: funct3=101");

        // ── Caso 4: JALR — ALUSrc=1, Jump=1 ──
        PCD=32'h18; PCPlus4D=32'h1C;
        RD1D=32'h200; RD2D=32'h0;
        ImmExtD=32'h0;
        Rs1D=5'd31; Rs2D=5'd0; RdD=5'd0;
        funct3D=3'b000; funct7D=7'b0; SubD=0;
        RegWriteD=0; ResultSrcD=2'b10; MemWriteD=0;
        JumpD=1; BranchD=0; ALUControlD=3'b000; ALUSrcD=1;
        check_propagation("JALR: Jump=1, ALUSrc=1");

        // ── Flush ──
        FlushE=1; #10; FlushE=0;
        @(posedge clk); #1;
        $display("--- FLUSH: SubE=%b funct3E=%b funct7E=%b (esperado 0)", SubE, funct3E, funct7E);

        $display("=== Fin testbench register_id_ex ===");
        $finish;
    end

endmodule