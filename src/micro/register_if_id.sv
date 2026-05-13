module register_if_id (
    input  logic        clk,
    input  logic        reset,
    input  logic        StallD,       // Señal de stall desde hazard unit
    input  logic        FlushD,       // Señal de flush desde hazard unit
    input  logic [31:0] PCF,          // PC actual (IF)
    input  logic [31:0] PCPlus4F,     // PC + 4 (para jump o branch calculado más adelante)
    input  logic [31:0] RD,           // Instrucción desde Instruction Memory

    output logic [31:0] PCD,          // PC para etapa ID
    output logic [31:0] PCPlus4D,     // PC + 4 para etapa ID
    output logic [31:0] InstrD        // Instrucción para etapa ID
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            PCD       <= 32'b0;
            PCPlus4D  <= 32'b0;
            InstrD    <= 32'b0;
        end else if (FlushD) begin
            PCD       <= 32'b0;
            PCPlus4D  <= 32'b0;
            InstrD    <= 32'b0;
        end else if (!StallD) begin
            PCD       <= PCF;
            PCPlus4D  <= PCPlus4F;
            InstrD    <= RD;
        end
        // Si StallD es 1, se mantienen los valores actuales (stall)
    end

endmodule




















/*

module register_if_id (
    input  logic        clk,
    input  logic        reset,
    input  logic        StallD,   // Para stall
    input  logic        FlushD,    // Para burbuja
    input  logic [31:0] pc_in,      // PC de la instrucción fetch
    input  logic [31:0] instr_in,   // Instrucción leída en memoria de instrucciones
    output logic [31:0] pc_out,     // PC a la etapa ID
    output logic [31:0] instr_out   // Instrucción a la etapa ID
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out    <= 32'b0;
            instr_out <= 32'b0;
        end else if (flush) begin
            pc_out    <= 32'b0;
            instr_out <= 32'b0;
        end else if (enable) begin
            pc_out    <= pc_in;
            instr_out <= instr_in;
        end
        // Si enable==0 (stall), mantiene los valores actuales.
    end

endmodule


*/
