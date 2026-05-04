module data_memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MEM_SIZE   = 256
)(
    input  logic                  clk,
    input  logic                  reset,          //Sincrono se limpia la memoria en el flanco 1
    input  logic                  WE,             // Señal de escritura (MemWriteM)
    input  logic [ADDR_WIDTH-1:0] A,              // Dirección de acceso
    input  logic [DATA_WIDTH-1:0] WD,             // Dato a escribir
    output logic [DATA_WIDTH-1:0] RD              // Dato leído
);

    // Memoria de datos
    logic [DATA_WIDTH-1:0] mem [0:MEM_SIZE-1];

    //indice para bucles 
    integer idx;

    //escritura sincrona y reset sincrono que limpia toda la memoria 
    always_ff @(posedge clk) begin
        if (reset) begin
            //Limpia la memoria cuando reset =1 (en el flanco)
            for (idx = 0; idx < MEM_SIZE; idx = idx + 1) 
                mem[idx] <= {DATA_WIDTH{1'b0}};
        end
        else if (WE) begin
            //Escritura por palabra (ignoramos bits [1:0] de A)
            mem[A[9:2]] <= WD;
        end
    end
    // Lectura asíncrona por palabra
    assign RD = mem [A[9:2]];

endmodule 

