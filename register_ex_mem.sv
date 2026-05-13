module register_ex_mem (
    input  logic        clk,
    input  logic        reset,

    // Datos desde EX
    input  logic [31:0] ALUResultE,
    input  logic [31:0] WriteDataE,
    input  logic [31:0] PCPlus4E,
    input  logic [4:0]  RdE,

    // Señales de control desde EX
    input  logic        RegWriteE,
    input  logic [1:0]  ResultSrcE,
    input  logic        MemWriteE,

    // Salidas hacia MEM
    output logic [31:0] ALUResultM,
    output logic [31:0] WriteDataM,
    output logic [31:0] PCPlus4M,
    output logic [4:0]  RdM,

    output logic        RegWriteM,
    output logic [1:0]  ResultSrcM,
    output logic        MemWriteM
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            ALUResultM  <= 32'b0;
            WriteDataM  <= 32'b0;
            PCPlus4M    <= 32'b0;
            RdM         <= 5'b0;

            RegWriteM   <= 1'b0;
            ResultSrcM  <= 2'b00;
            MemWriteM   <= 1'b0;
        end else begin
            ALUResultM  <= ALUResultE;
            WriteDataM  <= WriteDataE;
            PCPlus4M    <= PCPlus4E;
            RdM         <= RdE;

            RegWriteM   <= RegWriteE;
            ResultSrcM  <= ResultSrcE;
            MemWriteM   <= MemWriteE;
        end
    end

endmodule

