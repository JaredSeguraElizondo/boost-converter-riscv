module ALU (
    input  logic [31:0] operand1,
    input  logic [31:0] operand2,
    input  logic [2:0]  ALUControl,    // Señal de control de 3 bits
    input  logic [2:0]  funct3,        // Desde registro pipeline
    input  logic [6:0]  funct7,        // Desde registro pipeline (usado solo para sra/srai)
    input  logic        Sub,           // [FIX] Señal explicita de resta desde control_unit
    output logic [31:0] result,
    output logic        zero
);
    always_comb begin
        result = 32'b0;
        case (ALUControl)
            3'b000: begin // Aritmetico: add o sub
                // [FIX] Antes se usaba funct7 para decidir, lo cual fallaba
                //       para I-type (addi, jalr) cuyos bits [31:25] son parte
                //       del inmediato, no un funct7 real.
                //       Ahora la control_unit genera SubE = 1 solo para R-type sub.
                if (Sub)
                    result = operand1 - operand2;
                else
                    result = operand1 + operand2;
            end
            3'b001: begin // Desplazamiento izquierdo logico
                result = operand1 << operand2[4:0]; // sll, slli
            end
            3'b010: begin // Comparacion con signo
                result = ($signed(operand1) < $signed(operand2)) ? 32'd1 : 32'd0; // slt, slti
            end
            3'b011: begin // Comparacion sin signo
                result = (operand1 < operand2) ? 32'd1 : 32'd0; // sltu, sltiu
            end
            3'b100: result = operand1 ^ operand2; // xor, xori
            3'b101: begin // Desplazamiento derecho
                // funct7 sigue siendo valido aqui: sra/srai son R-type o I-type
                // donde bit 30 de la instruccion distingue logico vs aritmetico.
                // Para srai (I-type), el bit 30 es parte del encoding fijo (no del
                // inmediato variable), asi que es seguro usarlo.
                if (funct7[5])
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