module instruction_memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDRESS_WIDTH = 32,
    parameter MEM_SIZE = 256 //  256 instrucciones
    input logic [ADDRESS_WIDTH-1:0] address,
    output logic [DATA_WIDTH-1:0] instruction
);
    reg [DATA_WIDTH-1:0] IM [0:MEM_SIZE-1];

    initial begin
        $readmemh("module/Programa1.hex",IM);
    end

    assign instruction = IM[address[9:2]];
endmodule