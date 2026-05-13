module ALU (
    input  logic [31:0] operand1,
    input  logic [31:0] operand2,
    input  logic [2:0]  ALUControl,    // Señal de control de 3 bits
    input  logic [2:0]  funct3,        // Desde la salida de registro  InstrD
    input  logic [6:0]  funct7,        // Desde InstrD
    output logic [31:0] result,
    output logic        zero
);
    always_comb begin
        result = 32'b0;
        case (ALUControl)
            3'b000: begin // Aritmético: add, sub, jal, jalr, beq, bne
                if (funct3 == 3'b000 && funct7 == 7'b0100000)
                    result = operand1 - operand2; // sub, beq, bne
                else
                    result = operand1 + operand2; // add, addi, lw, sw, jal, jalr
            end
            3'b001: begin // Desplazamiento izquierdo lógico
                result = operand1 << operand2[4:0]; // sll, slli
            end
            3'b010: begin // Comparación con signo
                if (funct3 == 3'b010)
                    result = ($signed(operand1) < $signed(operand2)) ? 32'd1 : 32'd0; // slt, slti
                else
                    result = ($signed(operand1) >= $signed(operand2)) ? 32'd1 : 32'd0; // bge
            end
            3'b011: begin // Comparación sin signo
                if (funct3 == 3'b011)
                    result = (operand1 < operand2) ? 32'd1 : 32'd0; // sltu, sltui
                else
                    result = (operand1 >= operand2) ? 32'd1 : 32'd0; // blt (negado)
            end
            3'b100: result = operand1 ^ operand2; // xor, xori
            3'b101: begin // Desplazamiento derecho
                if (funct7 == 7'b0100000)
                    result = $signed(operand1) >>> operand2[4:0]; // sra, srai
                else
                    result = operand1 >> operand2[4:0];           // srl, srli
            end
            3'b110: result = operand1 | operand2; // or, ori
            3'b111: result = operand1 & operand2; // and, andi
            default: result = 32'b0;
        endcase
    end
    assign zero = (result == 32'b0);
endmodule