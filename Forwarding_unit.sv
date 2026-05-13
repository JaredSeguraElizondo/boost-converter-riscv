module forwarding_unit (
    input  logic [4:0] Rs1E, Rs2E,    // Registros fuente en EX
    input  logic [4:0] RdM, RdW,      // Registros destino en MEM y WB
    input  logic       RegWriteM,     // Escritura activa en MEM
    input  logic       RegWriteW,     // Escritura activa en WB
    output logic [1:0] ForwardAE,     // Selector para ALU input A
    output logic [1:0] ForwardBE      // Selector para ALU input B
);
    always_comb begin
        ForwardAE = 2'b00;
        ForwardBE = 2'b00;

        // Forwarding desde MEM
        if (RegWriteM && (RdM != 0) && (RdM == Rs1E))
            ForwardAE = 2'b10;
        if (RegWriteM && (RdM != 0) && (RdM == Rs2E))
            ForwardBE = 2'b10;

        // Forwarding desde WB
        if (RegWriteW && (RdW != 0) && (RdW == Rs1E) && !(RegWriteM && (RdM != 0) && (RdM == Rs1E)))
            ForwardAE = 2'b01;
        if (RegWriteW && (RdW != 0) && (RdW == Rs2E) && !(RegWriteM && (RdM != 0) && (RdM == Rs2E)))
            ForwardBE = 2'b01;
    end

endmodule
