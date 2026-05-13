`timescale 1ns / 1ps

// Módulo: vga_frame_buffer
// Descripción:
//   Buffer circular de 640 entradas que almacena la posición vertical (en
//   píxeles) de cada muestra de tensión para su graficación en VGA.
//
//   Puerto de escritura (desde vga_periph):
//     El CPU escribe la muestra ADC convertida ya como valor Y en píxeles
//     (0 = parte superior, 479 = parte inferior). El puntero de escritura
//     avanza circularmente con cada dato recibido.
//
//   Puerto de lectura (hacia vga_render):
//     Lectura asíncrona indexada por hcount (columna actual del barrido).
//     Así el módulo de render obtiene sin latencia el valor Y de la muestra
//     correspondiente a la columna que se está dibujando en ese momento.
//
//   Ancho de dato: 9 bits (suficiente para representar 0–479).
//   Profundidad   : 640 entradas (una por columna visible).



module vga_frame_buffer (
    input  logic        clk_i,       
    input  logic        rst_i,       

    //  Puerto de escritura 
    input  logic        we_i,        // Write-enable: escribe wr_data_i en wr_ptr
    input  logic [8:0]  wr_data_i,   // Valor Y en píxeles (0–479)

    //  Puerto de lectura 
    input  logic [9:0]  rd_addr_i,   // Columna del barrido (hcount, 0–639)
    output logic [8:0]  rd_data_o    // Valor Y almacenado para esa columna
);

    //  Memoria 
    logic [8:0] mem [0:639];

   
    initial begin
        for (int i = 0; i < 640; i++) mem[i] = 9'd479;
    end

    //  Puntero de escritura circular 
    logic [9:0] wr_ptr;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            wr_ptr <= '0;
        end else if (we_i) begin
            mem[wr_ptr] <= wr_data_i;
            wr_ptr      <= (wr_ptr == 10'd639) ? '0 : wr_ptr + 10'd1;
        end
    end

    // Lectura asíncrona
    assign rd_data_o = mem[rd_addr_i];

endmodule
