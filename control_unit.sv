module control_unit (
    input  logic [6:0] op,         // opcode
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,

    output logic       RegWriteD,
    output logic [1:0] ResultSrcD,
    output logic       MemWriteD,
    output logic       JumpD,
    output logic       BranchD,
    output logic [2:0] ALUControlD,
    output logic       ALUSrcD,
    output logic [1:0] ImmSrcD
);

    always_comb begin
        // Valores por defecto
        RegWriteD   = 0;
        ResultSrcD  = 2'b00;
        MemWriteD   = 0;
        JumpD       = 0;
        BranchD     = 0;
        ALUControlD = 3'b000;
        ALUSrcD     = 0;
        ImmSrcD     = 2'b00;

        case (op)
            7'b0000011: begin // lw
                RegWriteD   = 1;
                ResultSrcD  = 2'b01;
                MemWriteD   = 0;
                ALUSrcD     = 1;
                ALUControlD = 3'b000; // add
                ImmSrcD     = 2'b00;  // tipo I
            end

            7'b0100011: begin // sw
                RegWriteD   = 0;
                MemWriteD   = 1;
                ALUSrcD     = 1;
                ALUControlD = 3'b000; // add
                ImmSrcD     = 2'b01;  // tipo S
            end

            7'b0010011: begin // tipo I: addi, andi, ori, xori, slli, srli, srai, slti, sltiu
                RegWriteD   = 1;
                ResultSrcD  = 2'b00;
                MemWriteD   = 0;
                ALUSrcD     = 1;
                ImmSrcD     = 2'b00; // tipo I

                case (funct3)
                    3'b000: ALUControlD = 3'b000; // addi
                    3'b111: ALUControlD = 3'b111; // andi
                    3'b110: ALUControlD = 3'b110; // ori
                    3'b100: ALUControlD = 3'b100; // xori
                    3'b001: ALUControlD = 3'b001; // slli
                    3'b101: ALUControlD = 3'b101; // srli/srai → ALU decide por funct7
                    3'b010: ALUControlD = 3'b010; // slti
                    3'b011: ALUControlD = 3'b011; // sltiu
                endcase
            end

            7'b0110011: begin // tipo R: add, sub, and, or, xor, sll, srl, sra, slt, sltu
                RegWriteD   = 1;
                ResultSrcD  = 2'b00;
                MemWriteD   = 0;
                ALUSrcD     = 0;
                ImmSrcD     = 2'b00;

                case (funct3)
                    3'b000: ALUControlD = 3'b000; // add/sub → ALU distingue por funct7
                    3'b111: ALUControlD = 3'b111; // and
                    3'b110: ALUControlD = 3'b110; // or
                    3'b100: ALUControlD = 3'b100; // xor
                    3'b001: ALUControlD = 3'b001; // sll
                    3'b101: ALUControlD = 3'b101; // srl/sra
                    3'b010: ALUControlD = 3'b010; // slt
                    3'b011: ALUControlD = 3'b011; // sltu
                endcase
            end

            7'b1100011: begin // tipo B: beq, bne, blt, bge
                RegWriteD   = 0;
                BranchD     = 1;
                ALUSrcD     = 0;
                ALUControlD = 3'b000; // sub o cmp en ALU
                ImmSrcD     = 2'b10;  // tipo B
            end

            7'b1101111: begin // jal
                RegWriteD   = 1;
                JumpD       = 1;
                ResultSrcD  = 2'b10;
                ImmSrcD     = 2'b11;  // tipo J
            end

            7'b1100111: begin // jalr
                RegWriteD   = 1;
                JumpD       = 1;
                ResultSrcD  = 2'b10;
                ALUSrcD     = 1;
                ALUControlD = 3'b000; // add (base + offset)
                ImmSrcD     = 2'b00;  // tipo I
            end

            default: begin
                // NOP o instrucción inválida
                RegWriteD   = 0;
                ResultSrcD  = 2'b00;
                MemWriteD   = 0;
                JumpD       = 0;
                BranchD     = 0;
                ALUControlD = 3'b000;
                ALUSrcD     = 0;
                ImmSrcD     = 2'b00;
            end
        endcase
    end

endmodule