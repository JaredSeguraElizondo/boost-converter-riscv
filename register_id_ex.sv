
module register_id_ex (
    input  logic        clk,
    input  logic        reset,
    input  logic        FlushE,

    // Entradas desde ID
    input  logic [31:0] PCD,
    input  logic [31:0] PCPlus4D,
    input  logic [31:0] RD1D,
    input  logic [31:0] RD2D,
    input  logic [31:0] ImmExtD,
    input  logic [4:0]  Rs1D, Rs2D, RdD,
    input  logic [2:0]  funct3D,
    input  logic [6:0]  funct7D,

    input  logic        RegWriteD,
    input  logic [1:0]  ResultSrcD,
    input  logic        MemWriteD,
    input  logic        JumpD,
    input  logic        BranchD,
    input  logic [2:0]  ALUControlD,
    input  logic        ALUSrcD,

    // Salidas hacia EX
    output logic [31:0] PCE,
    output logic [31:0] PCPlus4E,
    output logic [31:0] RD1E,
    output logic [31:0] RD2E,
    output logic [31:0] ImmExtE,
    output logic [4:0]  Rs1E, Rs2E, RdE,
    output logic [2:0]  funct3E,
    output logic [6:0]  funct7E,

    output logic        RegWriteE,
    output logic [1:0]  ResultSrcE,
    output logic        MemWriteE,
    output logic        JumpE,
    output logic        BranchE,
    output logic [2:0]  ALUControlE,
    output logic        ALUSrcE
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset || FlushE) begin
            PCE         <= 32'b0;
            PCPlus4E    <= 32'b0;
            RD1E        <= 32'b0;
            RD2E        <= 32'b0;
            ImmExtE     <= 32'b0;
            Rs1E        <= 5'b0;
            Rs2E        <= 5'b0;
            RdE         <= 5'b0;
            funct3E     <= 3'b000;
            funct7E     <= 7'b0000000;

            RegWriteE   <= 1'b0;
            ResultSrcE  <= 2'b00;
            MemWriteE   <= 1'b0;
            JumpE       <= 1'b0;
            BranchE     <= 1'b0;
            ALUControlE <= 3'b000;
            ALUSrcE     <= 1'b0;
        end else begin
            PCE         <= PCD;
            PCPlus4E    <= PCPlus4D;
            RD1E        <= RD1D;
            RD2E        <= RD2D;
            ImmExtE     <= ImmExtD;
            Rs1E        <= Rs1D;
            Rs2E        <= Rs2D;
            RdE         <= RdD;
            funct3E     <= funct3D;
            funct7E     <= funct7D;

            RegWriteE   <= RegWriteD;
            ResultSrcE  <= ResultSrcD;
            MemWriteE   <= MemWriteD;
            JumpE       <= JumpD;
            BranchE     <= BranchD;
            ALUControlE <= ALUControlD;
            ALUSrcE     <= ALUSrcD;
        end
    end

endmodule






















/*

module register_id_ex (
    input  logic        clk,
    input  logic        reset,
    input  logic        StallD,   // Para stall
    input  logic        FlushE,    // Para burbuja

    // Datos de la etapa ID
    input  logic [31:0] RD1,        // Register Data 1 en ID
    input  logic [31:0] RD2,        // Register Data 2 en ID
    input  logic [31:0] PCD,         // PC en ID
    input  logic [4:0]  Rs1D,        // índice registro fuente 1
    input  logic [4:0]  Rs2D,        // índice registro fuente 2
    input  logic [4:0]  RdD,         // índice registro destino
    input  logic [31:0] ImmExtD,     // Inmediato extendido en ID
    input logic [31:0] PCPlus4D,   // PC + 4 en ID

    // Señales de control generadas en ID
    input  logic        RegWriteD,
    input  logic [1:0]  ResultSrcD,  // 2 bits, como en el libro
    input  logic        MemWriteD,
    input  logic        JumpD,
    input  logic        BranchD,
    input  logic [3:0]  ALUControlD,
    input  logic        ALUSrcD,
    input  logic [1:0]  ImmSrcD,


    // Salidas a la etapa EX
    output logic [31:0] RD1E,
    output logic [31:0] RD2E,
    output logic [31:0] PCE,
    output logic [4:0]  Rs1E,
    output logic [4:0]  Rs2E,
    output logic [4:0]  RdE,
    output logic [31:0] ImmExtE,

    output logic        RegWriteE,
    output logic [1:0]  ResultSrcE,
    output logic        MemWriteE,
    output logic        JumpE,
    output logic        BranchE,
    output logic [3:0]  ALUControlE,
    output logic        ALUSrcE,
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            PCE         <= 32'b0;
            RD1E        <= 32'b0;
            RD2E        <= 32'b0;
            ImmExtE     <= 32'b0;
            Rs1E        <= 5'b0;
            Rs2E        <= 5'b0;
            RdE         <= 5'b0;
            RegWriteE   <= 1'b0;
            ResultSrcE  <= 2'b0;
            MemWriteE   <= 1'b0;
            ALUControlE <= 4'b0;
            ALUSrcE     <= 1'b0;
            BranchE     <= 1'b0;
        end else if (enable) begin
            PCE         <= PCD;
            RD1E        <= RD1D;
            RD2E        <= RD2D;
            ImmExtE     <= ImmExtD;
            Rs1E        <= Rs1D;
            Rs2E        <= Rs2D;
            RdE         <= RdD;
            RegWriteE   <= RegWriteD;
            ResultSrcE  <= ResultSrcD;
            MemWriteE   <= MemWriteD;
            ALUControlE <= ALUControlD;
            ALUSrcE     <= ALUSrcD;
            BranchE     <= BranchD;
        end
        // Si enable == 0 (stall), mantiene valores actuales
    end

endmodule


*/