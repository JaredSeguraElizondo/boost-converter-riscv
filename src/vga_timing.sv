`timescale 1ns / 1ps

// Módulo: vga_timing
//   Generador de temporización VGA 640x480 @ 60 Hz.
//   Mantiene dos contadores (hcount, vcount) que barren el frame completo
//   de 800x525 píxeles, incluyendo los períodos de blanking. A partir de
//   estos contadores deriva las señales HSYNC, VSYNC y video_on.


module vga_timing (
    input  logic        clk_i,       // 25 MHz desde PLL
    input  logic        rst_i,       // Reset síncrono activo alto

    output logic [9:0]  hcount_o,    // Contador horizontal: 0 – 799
    output logic [9:0]  vcount_o,    // Contador vertical:   0 – 524
    output logic        hsync_o,     // HSYNC activo bajo
    output logic        vsync_o,     // VSYNC activo bajo
    output logic        video_on_o   // 1 cuando hcount y vcount están en zona visible
);

    // Parámetros de temporización 
    localparam int H_VISIBLE    = 640;
    localparam int H_FP         = 16;
    localparam int H_SYNC       = 96;
    localparam int H_BP         = 48;
    localparam int H_TOTAL      = H_VISIBLE + H_FP + H_SYNC + H_BP; // 800

    localparam int V_VISIBLE    = 480;
    localparam int V_FP         = 10;
    localparam int V_SYNC       = 2;
    localparam int V_BP         = 33;
    localparam int V_TOTAL      = V_VISIBLE + V_FP + V_SYNC + V_BP; // 525

    // Inicio y fin del pulso de sincronía (dentro del blanking)
    localparam int H_SYNC_START = H_VISIBLE + H_FP;           // 656
    localparam int H_SYNC_END   = H_VISIBLE + H_FP + H_SYNC;  // 752

    localparam int V_SYNC_START = V_VISIBLE + V_FP;           // 490
    localparam int V_SYNC_END   = V_VISIBLE + V_FP + V_SYNC;  // 492

    // Contadores de posición 
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            hcount_o <= '0;
            vcount_o <= '0;
        end else begin
            if (hcount_o == H_TOTAL - 1) begin
                hcount_o <= '0;
                vcount_o <= (vcount_o == V_TOTAL - 1) ? '0 : vcount_o + 10'd1;
            end else begin
                hcount_o <= hcount_o + 10'd1;
            end
        end
    end

    // Señales de sincronía
    assign hsync_o = ~( (hcount_o >= H_SYNC_START) && (hcount_o < H_SYNC_END) );
    assign vsync_o = ~( (vcount_o >= V_SYNC_START) && (vcount_o < V_SYNC_END) );

    // Zona visible 
    // Solo cuando ambos contadores están dentro del área activa
    assign video_on_o = (hcount_o < H_VISIBLE) && (vcount_o < V_VISIBLE);

endmodule