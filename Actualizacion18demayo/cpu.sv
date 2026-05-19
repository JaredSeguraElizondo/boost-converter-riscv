// ============================================================================
// Modulo: cpu
// Proyecto 3 -- Control digital RISC-V / Convertidor Boost
// Curso: EL3313 Taller de Diseño Digital
// ============================================================================
//   [FIX LUI] ImmSrcD ampliado de [1:0] a [2:0]
//   [FIX LUI] Rs1D_eff: para LUI fuerza Rs1=x0 (SrcA=0) en el banco de registros,
//             el hazard unit y el pipeline register.
//             Esto evita que bits [19:15] del inmediato U-type sean leidos
//             como una direccion de registro (e.g. lui x10,0x19 tiene Rs1=x9).
// ============================================================================

module cpu (
    input  logic        clk,
    input  logic        reset,

    output logic [31:0] ProgAddress_o,
    input  logic [31:0] ProgIn_i,

    output logic [31:0] DataAddress_o,
    output logic [31:0] DataOut_o,
    input  logic [31:0] DataIn_i,
    output logic        we_o
);

    // ========================================================================
    // 1. Señales internas
    // ========================================================================

    logic        StallF, StallD, FlushD, FlushE;
    logic [1:0]  ForwardAE, ForwardBE;
    logic        PCSrcE;

    // IF
    logic [31:0] PCF, PCF_Next, PCPlus4F, InstrF;

    // ID
    logic [31:0] InstrD, PCD, PCPlus4D;
    logic [31:0] RD1D, RD2D, ImmExtD;
    logic [31:0] ResultW;
    logic        RegWriteD, MemWriteD, JumpD, BranchD, ALUSrcD;
    logic [1:0]  ResultSrcD;
    logic [2:0]  ImmSrcD;          // [FIX LUI] era [1:0]
    logic [2:0]  ALUControlD;
    logic        SubD;

    // [FIX LUI] Rs1 efectivo: fuerza x0 para LUI para que SrcA = 0
    logic [4:0]  Rs1D_eff;
    assign Rs1D_eff = (InstrD[6:0] == 7'b0110111) ? 5'b00000 : InstrD[19:15];

    // EX
    logic [31:0] PCE, PCPlus4E, RD1E, RD2E, ImmExtE;
    logic [31:0] PCTargetE, SrcAE, SrcBE, ALUResultE, WriteDataE;
    logic        ZeroE;
    logic [4:0]  Rs1E, Rs2E, RdE;
    logic [2:0]  funct3E;
    logic [6:0]  funct7E;
    logic        RegWriteE, MemWriteE, JumpE, BranchE, ALUSrcE;
    logic [1:0]  ResultSrcE;
    logic [2:0]  ALUControlE;
    logic        SubE;
    logic        BranchTakenE;
    logic [31:0] JumpTargetE;

    // MEM
    logic [31:0] ALUResultM, WriteDataM, PCPlus4M, ReadDataM;
    logic [4:0]  RdM;
    logic        RegWriteM, MemWriteM;
    logic [1:0]  ResultSrcM;

    // WB
    logic [31:0] ALUResultW, ReadDataW, PCPlus4W;
    logic [4:0]  RdW;
    logic        RegWriteW;
    logic [1:0]  ResultSrcW;

    // ========================================================================
    // 2. Hazard y Forwarding
    // ========================================================================

    hazard_unit hu (
        .Rs1D       (Rs1D_eff),        // [FIX LUI] usa Rs1D_eff
        .Rs2D       (InstrD[24:20]),
        .RdE        (RdE),
        .ResultSrcE (ResultSrcE),
        .PCSrcE     (PCSrcE),
        .StallF     (StallF),
        .StallD     (StallD),
        .FlushD     (FlushD),
        .FlushE     (FlushE)
    );

    forwarding_unit fu (
        .Rs1E       (Rs1E),
        .Rs2E       (Rs2E),
        .RdM        (RdM),
        .RdW        (RdW),
        .RegWriteM  (RegWriteM),
        .RegWriteW  (RegWriteW),
        .ForwardAE  (ForwardAE),
        .ForwardBE  (ForwardBE)
    );

    // ========================================================================
    // 3. FETCH (IF)
    // ========================================================================

    mux21 #(32) mux_pc_src (
        .a   (PCPlus4F),
        .b   (JumpTargetE),
        .sel (PCSrcE),
        .f   (PCF_Next)
    );

    pc #(32) prog_counter (
        .clk    (clk),
        .reset  (reset),
        .StallF (StallF),
        .pc_in  (PCF_Next),
        .pc_out (PCF)
    );

    assign ProgAddress_o = PCF;
    assign InstrF        = ProgIn_i;

    adder #(32) pc_adder (
        .in1 (PCF),
        .in2 (32'd4),
        .out (PCPlus4F)
    );

    register_if_id reg_if_id (
        .clk     (clk),
        .reset   (reset),
        .StallD  (StallD),
        .FlushD  (FlushD),
        .PCF     (PCF),
        .PCPlus4F(PCPlus4F),
        .RD      (InstrF),
        .PCD     (PCD),
        .PCPlus4D(PCPlus4D),
        .InstrD  (InstrD)
    );

    // ========================================================================
    // 4. DECODE (ID)
    // ========================================================================

    control_unit cu (
        .op          (InstrD[6:0]),
        .funct3      (InstrD[14:12]),
        .funct7      (InstrD[31:25]),
        .RegWriteD   (RegWriteD),
        .ResultSrcD  (ResultSrcD),
        .MemWriteD   (MemWriteD),
        .JumpD       (JumpD),
        .BranchD     (BranchD),
        .ALUControlD (ALUControlD),
        .ALUSrcD     (ALUSrcD),
        .ImmSrcD     (ImmSrcD),
        .SubD        (SubD)
    );

    Reg_Bank rf (
        .clk (clk),
        .rst (reset),
        .WE3 (RegWriteW),
        .A1  (Rs1D_eff),               // [FIX LUI] usa Rs1D_eff
        .A2  (InstrD[24:20]),
        .A3  (RdW),
        .WD3 (ResultW),
        .RD1 (RD1D),
        .RD2 (RD2D)
    );

    ImmGen ig (
        .instruction (InstrD),
        .immSel      (ImmSrcD),
        .Imm         (ImmExtD)
    );

    register_id_ex reg_id_ex (
        .clk         (clk),
        .reset       (reset),
        .FlushE      (FlushE),
        .PCD         (PCD),
        .PCPlus4D    (PCPlus4D),
        .RD1D        (RD1D),
        .RD2D        (RD2D),
        .ImmExtD     (ImmExtD),
        .Rs1D        (Rs1D_eff),        // [FIX LUI] usa Rs1D_eff
        .Rs2D        (InstrD[24:20]),
        .RdD         (InstrD[11:7]),
        .funct3D     (InstrD[14:12]),
        .funct7D     (InstrD[31:25]),
        .RegWriteD   (RegWriteD),
        .ResultSrcD  (ResultSrcD),
        .MemWriteD   (MemWriteD),
        .JumpD       (JumpD),
        .BranchD     (BranchD),
        .ALUControlD (ALUControlD),
        .ALUSrcD     (ALUSrcD),
        .SubD        (SubD),
        .PCE         (PCE),
        .PCPlus4E    (PCPlus4E),
        .RD1E        (RD1E),
        .RD2E        (RD2E),
        .ImmExtE     (ImmExtE),
        .Rs1E        (Rs1E),
        .Rs2E        (Rs2E),
        .RdE         (RdE),
        .funct3E     (funct3E),
        .funct7E     (funct7E),
        .RegWriteE   (RegWriteE),
        .ResultSrcE  (ResultSrcE),
        .MemWriteE   (MemWriteE),
        .JumpE       (JumpE),
        .BranchE     (BranchE),
        .ALUControlE (ALUControlE),
        .ALUSrcE     (ALUSrcE),
        .SubE        (SubE)
    );

    // ========================================================================
    // 5. EXECUTE (EX)
    // ========================================================================

    always_comb begin
        case (funct3E)
            3'b000:  BranchTakenE = (SrcAE == WriteDataE);
            3'b001:  BranchTakenE = (SrcAE != WriteDataE);
            3'b100:  BranchTakenE = ($signed(SrcAE) < $signed(WriteDataE));
            3'b101:  BranchTakenE = ($signed(SrcAE) >= $signed(WriteDataE));
            3'b110:  BranchTakenE = (SrcAE < WriteDataE);
            3'b111:  BranchTakenE = (SrcAE >= WriteDataE);
            default: BranchTakenE = 1'b0;
        endcase
    end

    assign PCSrcE     = (BranchE & BranchTakenE) | JumpE;
    assign JumpTargetE = (JumpE & ALUSrcE) ? ALUResultE : PCTargetE;

    mux31 #(32) mux31A (
        .a   (RD1E),
        .b   (ResultW),
        .c   (ALUResultM),
        .sel (ForwardAE),
        .f   (SrcAE)
    );

    mux31 #(32) mux31B (
        .a   (RD2E),
        .b   (ResultW),
        .c   (ALUResultM),
        .sel (ForwardBE),
        .f   (WriteDataE)
    );

    mux21 #(32) mux_alu_src (
        .a   (WriteDataE),
        .b   (ImmExtE),
        .sel (ALUSrcE),
        .f   (SrcBE)
    );

    ALU alu (
        .operand1   (SrcAE),
        .operand2   (SrcBE),
        .ALUControl (ALUControlE),
        .funct3     (funct3E),
        .funct7     (funct7E),
        .Sub        (SubE),
        .result     (ALUResultE),
        .zero       (ZeroE)
    );

    adder #(32) branch_adder (
        .in1 (PCE),
        .in2 (ImmExtE),
        .out (PCTargetE)
    );

    register_ex_mem reg_ex_mem (
        .clk        (clk),
        .reset      (reset),
        .RegWriteE  (RegWriteE),
        .ResultSrcE (ResultSrcE),
        .MemWriteE  (MemWriteE),
        .ALUResultE (ALUResultE),
        .WriteDataE (WriteDataE),
        .PCPlus4E   (PCPlus4E),
        .RdE        (RdE),
        .RegWriteM  (RegWriteM),
        .ResultSrcM (ResultSrcM),
        .MemWriteM  (MemWriteM),
        .ALUResultM (ALUResultM),
        .WriteDataM (WriteDataM),
        .PCPlus4M   (PCPlus4M),
        .RdM        (RdM)
    );

    // ========================================================================
    // 6. MEMORY (MEM)
    // ========================================================================

    assign DataAddress_o = ALUResultM;
    assign DataOut_o     = WriteDataM;
    assign we_o          = MemWriteM;
    assign ReadDataM     = DataIn_i;

    register_mem_wb reg_mem_wb (
        .clk        (clk),
        .reset      (reset),
        .RegWriteM  (RegWriteM),
        .ResultSrcM (ResultSrcM),
        .ALUResultM (ALUResultM),
        .RD         (ReadDataM),
        .PCPlus4M   (PCPlus4M),
        .RdM        (RdM),
        .RegWriteW  (RegWriteW),
        .ResultSrcW (ResultSrcW),
        .ALUResultW (ALUResultW),
        .ReadDataW  (ReadDataW),
        .PCPlus4W   (PCPlus4W),
        .RdW        (RdW)
    );

    // ========================================================================
    // 7. WRITE BACK (WB)
    // ========================================================================

    mux31 #(32) mux31C (
        .a   (ALUResultW),
        .b   (ReadDataW),
        .c   (PCPlus4W),
        .sel (ResultSrcW),
        .f   (ResultW)
    );

endmodule