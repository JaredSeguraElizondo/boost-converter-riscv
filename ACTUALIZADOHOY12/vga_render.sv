`timescale 1ns / 1ps

// Modulo: vga_render
//   Generador de color por pixel para el plot de tension en VGA.
//   Dado (hcount, vcount) y el valor Y de la muestra en esa columna,
//   decide el color a emitir.
//
//   Capas de dibujo (orden de prioridad, mayor a menor):
//     1. Blanking    -> negro absoluto (video_on = 0)
//     2. Plot point  -> verde brillante si vcount == sample_y_i
//     3. Eje base    -> gris en la fila 479 (fondo de la grafica)
//     4. Fondo       -> azul oscuro
//
// [FIX CDC] El registro de salida ahora se actualiza solo con pix_en_i
//   para que el color cambie a la tasa de pixel (25 MHz), no a 100 MHz.
//   Esto mantiene el timing VGA correcto en los pines de salida.


module vga_render (
    input  logic        clk_i,       // 100 MHz
    input  logic        pix_en_i,    // [FIX CDC] Pixel enable

    // Senales de posicion
    input  logic        video_on_i,  // 1 = zona visible activa
    input  logic [9:0]  hcount_i,    // Columna actual (0-639 visible)
    input  logic [9:0]  vcount_i,    // Fila actual    (0-479 visible)

    // Dato de muestra
    input  logic [8:0]  sample_y_i,  // Posicion Y de la muestra en esta columna

    // Salidas de color hacia el conector VGA (4 bits por canal)
    output logic [3:0]  red_o,
    output logic [3:0]  grn_o,
    output logic [3:0]  blu_o
);

    // Logica de seleccion de capa
    logic plot_pixel;
    logic axis_pixel;

    assign plot_pixel = video_on_i && (vcount_i == {1'b0, sample_y_i});
    assign axis_pixel = video_on_i && (vcount_i == 10'd479);

    // Registro de salida -- actualiza solo en pix_en_i
    always_ff @(posedge clk_i) begin
        if (pix_en_i) begin
            if (!video_on_i) begin
                // Blanking: negro absoluto
                red_o <= 4'h0;
                grn_o <= 4'h0;
                blu_o <= 4'h0;
            end else if (plot_pixel) begin
                // Punto del plot: verde brillante
                red_o <= 4'h0;
                grn_o <= 4'hF;
                blu_o <= 4'h0;
            end else if (axis_pixel) begin
                // Eje base inferior: gris medio
                red_o <= 4'h5;
                grn_o <= 4'h5;
                blu_o <= 4'h5;
            end else begin
                // Fondo: azul muy oscuro
                red_o <= 4'h0;
                grn_o <= 4'h0;
                blu_o <= 4'h2;
            end
        end
    end

endmodule