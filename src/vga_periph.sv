`timescale 1ns / 1ps

// Modulo: vga_periph
//   Periferico VGA mapeado en memoria. Ensambla los tres submodulos
//   (vga_timing, vga_frame_buffer, vga_render) y expone la interfaz
//   estandar del bus de datos del microcontrolador RISC-V.
//
// [FIX CDC] Todo el modulo corre ahora en el reloj del CPU (100 MHz).
//   Un divisor interno de 2 bits genera pix_en cada 4 ciclos, lo que
//   equivale a un pixel clock de 25 MHz. Esto elimina el cruce de
//   dominios que causaba que ~75% de las escrituras del bus se perdieran.
//   Ya no se necesita un PLL externo de 25 MHz para VGA.
//
// Mapa de registros internos (offset_i = address[3:0]):
//   Offset 0x00 -- Registro de Control (R/W)
//     bit  0    : enable   -- habilita salidas VGA (HSYNC/VSYNC/RGB)
//     bits 31:1 : reservado
//   Offset 0x04 -- Registro de Dato de Plot (W)
//     bits 11:0 : adc_sample -- valor ADC de 12 bits (0-4095)
//     bits 31:12: ignorados
//
// Conversion ADC -> Y pixel:
//   Y = 479 - floor((adc_sample * 480) / 4096)


module vga_periph (
    input  logic        clk_i,       // 100 MHz (reloj del CPU)
    input  logic        rst_i,       // Reset sincrono activo alto

    // Interfaz con el bus de datos del CPU
    input  logic [3:0]  offset_i,    // address[3:0]: selecciona registro interno
    input  logic [31:0] wdata_i,     // Dato de escritura del CPU
    input  logic        we_i,        // Write-enable desde address_decoder
    output logic [31:0] rdata_o,     // Dato de lectura hacia el CPU

    // Salidas fisicas hacia el conector VGA de la Basys 3
    output logic        hsync_o,     // HSYNC al monitor
    output logic        vsync_o,     // VSYNC al monitor
    output logic [3:0]  red_o,       // Canal rojo   (4 bits)
    output logic [3:0]  grn_o,       // Canal verde  (4 bits)
    output logic [3:0]  blu_o        // Canal azul   (4 bits)
);

    // =========================================================================
    // [FIX CDC] Divisor de pixel: genera pix_en cada 4 ciclos de 100 MHz
    //           equivalente a 25 MHz pixel clock
    // =========================================================================
    logic [1:0] pix_div;
    logic       pix_en;

    always_ff @(posedge clk_i) begin
        if (rst_i) pix_div <= 2'b00;
        else       pix_div <= pix_div + 2'b01;
    end
    assign pix_en = (pix_div == 2'b00);

    // =========================================================================
    // Registro de control (dominio CPU -- sin CDC, misma clk)
    // =========================================================================
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

    // =========================================================================
    // Conversion ADC a posicion Y en pixeles
    // =========================================================================
    logic [11:0] adc_sample;
    logic [20:0] y_scaled;   // sample * 480, maximo 4095*480 = 1,965,600 < 2^21
    logic [8:0]  y_pixel;    // valor Y resultante (0-479)
    logic        fb_we;

    assign adc_sample = wdata_i[11:0];
    assign y_scaled   = adc_sample * 9'd480;
    assign y_pixel    = 9'd479 - y_scaled[20:12];

    // Solo escribe en el buffer cuando esta habilitado y el CPU escribe en offset 0x04
    assign fb_we = we_i && ctrl_enable && (offset_i[3:2] == 2'b01);

    // =========================================================================
    // Senales internas entre submodulos
    // =========================================================================
    logic [9:0] hcount, vcount;
    logic       hsync_int, vsync_int, video_on;
    logic [8:0] sample_y;
    logic [3:0] red_int, grn_int, blu_int;

    // =========================================================================
    // Instancias de submodulos (todos en 100 MHz)
    // =========================================================================
    vga_timing u_timing (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .pix_en_i   (pix_en),       // [FIX CDC] pixel enable
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
        .pix_en_i   (pix_en),       // [FIX CDC] pixel enable
        .video_on_i (video_on),
        .hcount_i   (hcount),
        .vcount_i   (vcount),
        .sample_y_i (sample_y),
        .red_o      (red_int),
        .grn_o      (grn_int),
        .blu_o      (blu_int)
    );

    // =========================================================================
    // Control de salidas
    // =========================================================================
    assign hsync_o = ctrl_enable ? hsync_int : 1'b1;
    assign vsync_o = ctrl_enable ? vsync_int : 1'b1;
    assign red_o   = ctrl_enable ? red_int   : 4'h0;
    assign grn_o   = ctrl_enable ? grn_int   : 4'h0;
    assign blu_o   = ctrl_enable ? blu_int   : 4'h0;

endmodule