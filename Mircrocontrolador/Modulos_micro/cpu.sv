// Descripción:
//   Procesador RISC-V rv32i con pipeline de 5 etapas (IF/ID/EX/MEM/WB),
//   forwarding y detección de hazards.
//
//   Adaptado del Proyecto 2 (Alejandro Bejarano) con las siguientes
//   correcciones y modificaciones:
//
//   [FIX 1] funct3E/funct7E ahora se conectan a la ALU (antes hardcodeados)
//   [FIX 2] Branch comparator dedicado para beq/bne/blt/bge
//   [FIX 3] jalr usa ALU result (rs1+imm) como target, no PC+imm
//   [FIX 4] Punto y coma faltante en mux31B
//   [MOD 1] Buses de datos externalizados (DataAddress, DataOut, DataIn, we)
//   [MOD 2] Bus de instrucciones externalizado (ProgAddress, ProgIn)
//
//   La data_memory y instruction_memory ya NO están instanciadas aquí.
//   Se conectan externamente junto con el address_decoder y read_mux.
// ============================================================================

module cpu (
    input  logic        clk,
    input  logic        reset,

    // ── Bus de instrucciones (Harvard — ROM externa) ──  [MOD 2]
    output logic [31:0] ProgAddress_o,     // PC → dirección de ROM
    input  logic [31:0] ProgIn_i,          // Instrucción leída de ROM

    // ── Bus de datos (Harvard — RAM + periféricos externos) ──  [MOD 1]
    output logic [31:0] DataAddress_o,     // Dirección de dato (ALUResultM)
    output logic [31:0] DataOut_o,         // Dato a escribir (WriteDataM)
    input  logic [31:0] DataIn_i,          // Dato leído (del read_mux)
    output logic        we_o               // Write-enable global
);

    // ========================================================================
    // 1. Declaración de señales internas por etapa
    // ========================================================================

    // ── Hazard & Control ──
    logic        StallF, StallD, FlushD, FlushE;
    logic [1:0]  ForwardAE, ForwardBE;
    logic        PCSrcE;

    // ── Fetch (IF) ──
    logic [31:0] PCF, PCF_Next, PCPlus4F, InstrF;

    // ── Decode (ID) ──
    logic [31:0] InstrD, PCD, PCPlus4D;
    logic [31:0] RD1D, RD2D, ImmExtD;
    logic [31:0] ResultW;
    logic        RegWriteD, MemWriteD, JumpD, BranchD, ALUSrcD;
    logic [1:0]  ResultSrcD, ImmSrcD;
    logic [2:0]  ALUControlD;

    // ── Execute (EX) ──
    logic [31:0] PCE, PCPlus4E, RD1E, RD2E, ImmExtE;
    logic [31:0] PCTargetE, SrcAE, SrcBE, ALUResultE, WriteDataE;
    logic        ZeroE;
    logic [4:0]  Rs1E, Rs2E, RdE;
    logic [2:0]  funct3E;       // [FIX 1] — señales que faltaban en el top
    logic [6:0]  funct7E;       // [FIX 1]
    logic        RegWriteE, MemWriteE, JumpE, BranchE, ALUSrcE;
    logic [1:0]  ResultSrcE;
    logic [2:0]  ALUControlE;
    logic        BranchTakenE;  // [FIX 2] — resultado del comparador de branches
    logic [31:0] JumpTargetE;   // [FIX 3] — target mux para jal vs jalr

    // ── Memory (MEM) ──
    logic [31:0] ALUResultM, WriteDataM, PCPlus4M, ReadDataM;
    logic [4:0]  RdM;
    logic        RegWriteM, MemWriteM;
    logic [1:0]  ResultSrcM;

    // ── Write Back (WB) ──
    logic [31:0] ALUResultW, ReadDataW, PCPlus4W;
    logic [4:0]  RdW;
    logic        RegWriteW;
    logic [1:0]  ResultSrcW;

    // ========================================================================
    // 2. Unidades de Hazard y Forwarding
    // ========================================================================

    hazard_unit hu (
        .Rs1D       (InstrD[19:15]),
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
    // 3. Etapa FETCH (IF)
    // ========================================================================

    // Mux PC: selecciona entre PC+4 y target de salto/branch
    mux21 #(32) mux_pc_src (
        .a   (PCPlus4F),
        .b   (JumpTargetE),   // [FIX 3] — era PCTargetE, ahora pasa por mux
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

    // [MOD 2] ROM externalizada — conectamos el bus de instrucciones
    assign ProgAddress_o = PCF;
    assign InstrF        = ProgIn_i;

    // Adder PC + 4
    adder #(32) pc_adder (
        .in1 (PCF),
        .in2 (32'd4),
        .out (PCPlus4F)
    );

    // Registro IF/ID
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
    // 4. Etapa DECODE (ID)
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
        .ImmSrcD     (ImmSrcD)
    );

    Reg_Bank rf (
        .clk (clk),
        .rst (reset),
        .WE3 (RegWriteW),
        .A1  (InstrD[19:15]),
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

    // Registro ID/EX
    register_id_ex reg_id_ex (
        .clk         (clk),
        .reset       (reset),
        .FlushE      (FlushE),
        // Datos
        .PCD         (PCD),
        .PCPlus4D    (PCPlus4D),
        .RD1D        (RD1D),
        .RD2D        (RD2D),
        .ImmExtD     (ImmExtD),
        .Rs1D        (InstrD[19:15]),
        .Rs2D        (InstrD[24:20]),
        .RdD         (InstrD[11:7]),
        .funct3D     (InstrD[14:12]),
        .funct7D     (InstrD[31:25]),
        // Control
        .RegWriteD   (RegWriteD),
        .ResultSrcD  (ResultSrcD),
        .MemWriteD   (MemWriteD),
        .JumpD       (JumpD),
        .BranchD     (BranchD),
        .ALUControlD (ALUControlD),
        .ALUSrcD     (ALUSrcD),
        // Salidas — Datos
        .PCE         (PCE),
        .PCPlus4E    (PCPlus4E),
        .RD1E        (RD1E),
        .RD2E        (RD2E),
        .ImmExtE     (ImmExtE),
        .Rs1E        (Rs1E),
        .Rs2E        (Rs2E),
        .RdE         (RdE),
        .funct3E     (funct3E),         // [FIX 1] — ahora conectados
        .funct7E     (funct7E),         // [FIX 1]
        // Salidas — Control
        .RegWriteE   (RegWriteE),
        .ResultSrcE  (ResultSrcE),
        .MemWriteE   (MemWriteE),
        .JumpE       (JumpE),
        .BranchE     (BranchE),
        .ALUControlE (ALUControlE),
        .ALUSrcE     (ALUSrcE)
    );

    // ========================================================================
    // 5. Etapa EXECUTE (EX)
    // ========================================================================

    // ── [FIX 2] Comparador de branches dedicado ──
    // Evalúa la condición de salto según funct3, independiente de la ALU.
    // Usa los operandos con forwarding aplicado (SrcAE y WriteDataE).
    always_comb begin
        case (funct3E)
            3'b000:  BranchTakenE = (SrcAE == WriteDataE);                          // beq
            3'b001:  BranchTakenE = (SrcAE != WriteDataE);                          // bne
            3'b100:  BranchTakenE = ($signed(SrcAE) < $signed(WriteDataE));         // blt
            3'b101:  BranchTakenE = ($signed(SrcAE) >= $signed(WriteDataE));        // bge
            3'b110:  BranchTakenE = (SrcAE < WriteDataE);                           // bltu
            3'b111:  BranchTakenE = (SrcAE >= WriteDataE);                          // bgeu
            default: BranchTakenE = 1'b0;
        endcase
    end

    // Decisión final de salto
    assign PCSrcE = (BranchE & BranchTakenE) | JumpE;

    // ── [FIX 3] Mux de target: jal usa PC+imm, jalr usa ALU result (rs1+imm) ──
    // Distinguimos jalr porque tiene JumpE=1 y ALUSrcE=1 (jal no usa ALUSrcE)
    assign JumpTargetE = (JumpE & ALUSrcE) ? ALUResultE : PCTargetE;

    // Forwarding mux A (operando 1)
    mux31 #(32) mux31A (
        .a   (RD1E),
        .b   (ResultW),
        .c   (ALUResultM),
        .sel (ForwardAE),
        .f   (SrcAE)
    );

    // Forwarding mux B (operando 2 / dato de store)
    mux31 #(32) mux31B (
        .a   (RD2E),
        .b   (ResultW),
        .c   (ALUResultM),
        .sel (ForwardBE),
        .f   (WriteDataE)              // [FIX 4] — punto y coma corregido
    );

    // Mux ALU source B: registro (R-type) vs inmediato (I/S-type)
    mux21 #(32) mux_alu_src (
        .a   (WriteDataE),
        .b   (ImmExtE),
        .sel (ALUSrcE),
        .f   (SrcBE)
    );

    // ALU Principal
    ALU alu (
        .operand1   (SrcAE),
        .operand2   (SrcBE),
        .ALUControl (ALUControlE),
        .funct3     (funct3E),         // [FIX 1] — antes era 3'b000
        .funct7     (funct7E),         // [FIX 1] — antes era 7'b0000000
        .result     (ALUResultE),
        .zero       (ZeroE)            // Ya no se usa para branches, pero se mantiene
    );

    // Adder para cálculo de salto relativo a PC (jal, branches)
    adder #(32) branch_adder (
        .in1 (PCE),
        .in2 (ImmExtE),
        .out (PCTargetE)
    );

    // Registro EX/MEM
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
    // 6. Etapa MEMORY (MEM)
    // ========================================================================

    // [MOD 1] — Data memory externalizada.
    //   Antes: data_memory estaba instanciada aquí adentro.
    //   Ahora: el bus sale por los puertos del módulo para conectarse
    //          al address_decoder y read_mux que ya diseñamos.

    assign DataAddress_o = ALUResultM;      // Dirección = resultado de ALU
    assign DataOut_o     = WriteDataM;      // Dato a escribir
    assign we_o          = MemWriteM;       // Write-enable global
    assign ReadDataM     = DataIn_i;        // Dato leído (viene del read_mux)

    // Registro MEM/WB
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
    // 7. Etapa WRITE BACK (WB)
    // ========================================================================

    mux31 #(32) mux31C (
        .a   (ALUResultW),
        .b   (ReadDataW),
        .c   (PCPlus4W),
        .sel (ResultSrcW),
        .f   (ResultW)
    );

endmodule