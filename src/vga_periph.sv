`timescale 1ns / 1ps

// Módulo: vga_periph
//   Periférico VGA mapeado en memoria. Ensambla los tres submódulos
//   (vga_timing, vga_frame_buffer, vga_render) y expone la interfaz
//   estándar del bus de datos del microcontrolador RISC-V.
// Mapa de registros internos (address[3:0] = offset_i):
//   Offset 0x00 — Registro de Control (R/W)
//     bit  0    : enable   — habilita salidas VGA (HSYNC/VSYNC/RGB)
//     bits 31:1 : reservado
//   Offset 0x04 — Registro de Dato de Plot (W)
//     bits 11:0 : adc_sample — valor ADC de 12 bits (0–4095)
//                 Al escribir, se convierte a posición Y en píxeles y se
//                 almacena en el siguiente slot del buffer circular.
//     bits 31:12: ignorados
// Conversión ADC → Y píxel:
//   Y = 479 − ⌊(adc_sample × 480) / 4096⌋
//   → adc = 0    : Y = 479  (fondo de pantalla, 0 V)
//   → adc = 2048 : Y = 239  (mitad de pantalla)
//   → adc = 4095 : Y = 0    (tope de pantalla, tensión máxima)
// Comportamiento cuando enable = 0:
//   HSYNC y VSYNC se mantienen en alto (inactivos).
//   RGB se fuerza a cero. Los contadores internos siguen corriendo para
//   que al re-habilitar el monitor se sincronice rápidamente.


module vga_periph (
    input  logic        clk_i,       // 25 MHz desde PLL
    input  logic        rst_i,       // Reset síncrono activo alto

    // Interfaz con el bus de datos del CPU 
    input  logic [3:0]  offset_i,    // address[3:0]: selecciona registro interno
    input  logic [31:0] wdata_i,     // Dato de escritura del CPU
    input  logic        we_i,        // Write-enable desde address_decoder
    output logic [31:0] rdata_o,     // Dato de lectura hacia el CPU

    // Salidas físicas hacia el conector VGA de la Basys 3 
    output logic        hsync_o,     // HSYNC al monitor
    output logic        vsync_o,     // VSYNC al monitor
    output logic [3:0]  red_o,       // Canal rojo   (4 bits)
    output logic [3:0]  grn_o,       // Canal verde  (4 bits)
    output logic [3:0]  blu_o        // Canal azul   (4 bits)
);

    // Registro de control
    logic ctrl_enable;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            ctrl_enable <= 1'b0;
        end else if (we_i && (offset_i[3:2] == 2'b00)) begin
            ctrl_enable <= wdata_i[0];
        end
    end

    // Lectura de registros 
    always_comb begin
        case (offset_i[3:2])
            2'b00:   rdata_o = {31'b0, ctrl_enable};
            default: rdata_o = 32'b0;   // offset 0x04 es write-only
        endcase
    end

    // Conversión ADC a posición Y en píxeles
    // Se hace combinacionalmente al recibir la escritura, evitando
    // almacenar el valor ADC raw en el buffer.
    //
    // Cálculo: Y = 479 - floor((sample * 480) / 4096)
    //   La división por 4096 es un shift derecho de 12 bits.
    //   El producto sample(12 bits) × 480(9 bits) requiere 21 bits.

    logic [11:0] adc_sample;
    logic [20:0] y_scaled;   // sample * 480, máximo 4095*480 = 1,965,600 < 2^21
    logic [8:0]  y_pixel;    // valor Y resultante (0–479)
    logic        fb_we;

    assign adc_sample = wdata_i[11:0];
    assign y_scaled   = adc_sample * 9'd480;
    assign y_pixel    = 9'd479 - y_scaled[20:12]; // equivale a >> 12 dentro del rango

    // Solo escribe en el buffer cuando está habilitado y el CPU escribe en offset 0x04
    assign fb_we = we_i && ctrl_enable && (offset_i[3:2] == 2'b01);

    // Señales internas entre submódulos
    logic [9:0] hcount, vcount;
    logic       hsync_int, vsync_int, video_on;
    logic [8:0] sample_y;
    logic [3:0] red_int, grn_int, blu_int;

    // Instancias de submódulos
    vga_timing u_timing (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .hcount_o   (hcount),
        .vcount_o   (vcount),
        .hsync_o    (hsync_int),
        .vsync_o    (vsync_int),
        .video_on_o (video_on)
    );

    vga_frame_buffer u_frame_buffer (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .we_i       (fb_we),
        .wr_data_i  (y_pixel),
        .rd_addr_i  (hcount),
        .rd_data_o  (sample_y)
    );

    vga_render u_render (
        .clk_i      (clk_i),
        .video_on_i (video_on),
        .hcount_i   (hcount),
        .vcount_i   (vcount),
        .sample_y_i (sample_y),
        .red_o      (red_int),
        .grn_o      (grn_int),
        .blu_o      (blu_int)
    );

    // Control de salidas 
    // Cuando está deshabilitado: sync inactivos (alto), RGB en cero.
    // Los contadores de timing siguen corriendo internamente para
    // facilitar la re-sincronización del monitor al re-habilitar.
    assign hsync_o = ctrl_enable ? hsync_int : 1'b1;
    assign vsync_o = ctrl_enable ? vsync_int : 1'b1;
    assign red_o   = ctrl_enable ? red_int   : 4'h0;
    assign grn_o   = ctrl_enable ? grn_int   : 4'h0;
    assign blu_o   = ctrl_enable ? blu_int   : 4'h0;

endmodule