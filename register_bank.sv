module Reg_Bank (
    input  logic        clk,
    input  logic        rst,
    input  logic        WE3,        // enable para escritura
    input  logic [ 4:0] A1 ,        // direccion de lectura 1
    input  logic [ 4:0] A2 ,        // direccion de lectura 2
    input  logic [ 4:0] A3 ,        // direccion de escritura
    input  logic [31:0] WD3,        // entrada de datos a escribir

    output logic [31:0] RD1,        // salida de datos de A1
    output logic [31:0] RD2         // salida de datos de A2
    );

    //arreglo de memoria dinamica 
    logic [31:0] mem [31:0];
    int i;

    //logica de escritura
    always_ff @(posedge clk) begin                  // en el flanco de subida del reloj
        if (rst) begin 
            for (i = 0; i<32; i++) 
            mem[i] <= 32'b0;                        //reset a 0, inicializa el banco de registros, 
        end
        else if (WE3 && (A3 != 0)) begin      //si WE3 es alto y A3 es 0, se escribe en el registro 0
            mem[A3] <= WD3;                        //escribe el valor de WD3 en el registro 0
        end
    end 
    assign RD1 = (A1 == 0) ? 32'b0 : mem[A1];       //si A1 es 0, RD1 es 0, si no, RD1 es el valor del registro A1
    assign RD2 = (A2 == 0) ? 32'b0 : mem[A2];       //si A2 es 0, RD2 es 0, si no, RD2 es el valor del registro A2
endmodule