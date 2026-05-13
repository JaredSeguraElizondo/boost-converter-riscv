module register_mem_wb (
    input  logic        clk,
    input  logic        reset,

    // Entradas desde MEM
    input  logic        RegWriteM,
    input  logic [1:0]  ResultSrcM,
    input  logic [31:0] ALUResultM,
    input  logic [31:0] RD,            // Read Data desde Data Memory
    input  logic [31:0] PCPlus4M,
    input  logic [4:0]  RdM,

    // Salidas hacia WB
    output logic        RegWriteW,
    output logic [1:0]  ResultSrcW,
    output logic [31:0] ALUResultW,
    output logic [31:0] ReadDataW,
    output logic [31:0] PCPlus4W,
    output logic [4:0]  RdW
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            RegWriteW   <= 1'b0;
            ResultSrcW  <= 2'b00;
            ALUResultW  <= 32'b0;
            ReadDataW   <= 32'b0;
            PCPlus4W    <= 32'b0;
            RdW         <= 5'b0;
        end else begin
            RegWriteW   <= RegWriteM;
            ResultSrcW  <= ResultSrcM;
            ALUResultW  <= ALUResultM;
            ReadDataW   <= RD;
            PCPlus4W    <= PCPlus4M;
            RdW         <= RdM;
        end
    end

endmodule
