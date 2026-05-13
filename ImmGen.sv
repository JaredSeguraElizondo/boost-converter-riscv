module ImmGen(
    input logic [31:0] instruction, //entrada de la instrucción
    input logic [1:0] immSel,       //selector de inmediato
    output logic [31:0] Imm         //inmediato de salida
    );
// I, S, B, J
    always_comb begin
        case (immSel)
            2'b00: Imm = { {20{instruction[31]}}, instruction[31:20] }; // I
            2'b01: Imm = { {20{instruction[31]}}, instruction[31:25], instruction[11:7] }; // S
            2'b10: Imm = { {19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0 }; // B
            2'b11: Imm = { {12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0 }; // J
            default: Imm = 32'b0;   // Valor por defecto
        endcase
    end
endmodule