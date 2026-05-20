module ImmGen(
    input  logic [31:0] instruction,
    input  logic [2:0]  immSel,     // [FIX LUI] ampliado de [1:0] a [2:0]
    output logic [31:0] Imm
);
    always_comb begin
        case (immSel)
            3'b000: Imm = { {20{instruction[31]}}, instruction[31:20] };                                          // I-type
            3'b001: Imm = { {20{instruction[31]}}, instruction[31:25], instruction[11:7] };                       // S-type
            3'b010: Imm = { {19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0 }; // B-type
            3'b011: Imm = { {12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0 }; // J-type
            3'b100: Imm = { instruction[31:12], 12'b0 };                                                          // [FIX LUI] U-type
            default: Imm = 32'b0;
        endcase
    end
endmodule