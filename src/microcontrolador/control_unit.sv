module control_unit (
    input  logic [6:0] op,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,

    output logic       RegWriteD,
    output logic [1:0] ResultSrcD,
    output logic       MemWriteD,
    output logic       JumpD,
    output logic       BranchD,
    output logic [2:0] ALUControlD,
    output logic       ALUSrcD,
    output logic [2:0] ImmSrcD,    // [FIX LUI] ampliado de [1:0] a [2:0]
    output logic       SubD
);

    always_comb begin
        RegWriteD   = 0;
        ResultSrcD  = 2'b00;
        MemWriteD   = 0;
        JumpD       = 0;
        BranchD     = 0;
        ALUControlD = 3'b000;
        ALUSrcD     = 0;
        ImmSrcD     = 3'b000;
        SubD        = 0;

        case (op)
            7'b0000011: begin // lw
                RegWriteD   = 1;
                ResultSrcD  = 2'b01;
                ALUSrcD     = 1;
                ALUControlD = 3'b000;
                ImmSrcD     = 3'b000;  // I-type
            end

            7'b0100011: begin // sw
                MemWriteD   = 1;
                ALUSrcD     = 1;
                ALUControlD = 3'b000;
                ImmSrcD     = 3'b001;  // S-type
            end

            7'b0010011: begin // I-type ALU
                RegWriteD   = 1;
                ALUSrcD     = 1;
                ImmSrcD     = 3'b000;
                case (funct3)
                    3'b000: ALUControlD = 3'b000;
                    3'b111: ALUControlD = 3'b111;
                    3'b110: ALUControlD = 3'b110;
                    3'b100: ALUControlD = 3'b100;
                    3'b001: ALUControlD = 3'b001;
                    3'b101: ALUControlD = 3'b101;
                    3'b010: ALUControlD = 3'b010;
                    3'b011: ALUControlD = 3'b011;
                endcase
            end

            7'b0110011: begin // R-type
                RegWriteD   = 1;
                ALUSrcD     = 0;
                SubD = (funct3 == 3'b000 && funct7 == 7'b0100000) ? 1 : 0;
                case (funct3)
                    3'b000: ALUControlD = 3'b000;
                    3'b111: ALUControlD = 3'b111;
                    3'b110: ALUControlD = 3'b110;
                    3'b100: ALUControlD = 3'b100;
                    3'b001: ALUControlD = 3'b001;
                    3'b101: ALUControlD = 3'b101;
                    3'b010: ALUControlD = 3'b010;
                    3'b011: ALUControlD = 3'b011;
                endcase
            end

            7'b1100011: begin // B-type
                BranchD     = 1;
                ALUSrcD     = 0;
                ALUControlD = 3'b000;
                ImmSrcD     = 3'b010;  // B-type
            end

            7'b1101111: begin // jal
                RegWriteD  = 1;
                JumpD      = 1;
                ResultSrcD = 2'b10;
                ImmSrcD    = 3'b011;  // J-type
            end

            7'b1100111: begin // jalr
                RegWriteD   = 1;
                JumpD       = 1;
                ResultSrcD  = 2'b10;
                ALUSrcD     = 1;
                ALUControlD = 3'b000;
                ImmSrcD     = 3'b000;  // I-type
            end

            // [FIX LUI] Instruccion LUI completamente nueva
            7'b0110111: begin // LUI
                RegWriteD   = 1;
                ResultSrcD  = 2'b00;
                ALUSrcD     = 1;       // usa inmediato U-type como SrcB
                ALUControlD = 3'b000;  // add: 0 + Imm = Imm
                ImmSrcD     = 3'b100;  // U-type
            end

            default: begin
                RegWriteD   = 0;
                ResultSrcD  = 2'b00;
                MemWriteD   = 0;
                JumpD       = 0;
                BranchD     = 0;
                ALUControlD = 3'b000;
                ALUSrcD     = 0;
                ImmSrcD     = 3'b000;
                SubD        = 0;
            end
        endcase
    end

endmodule