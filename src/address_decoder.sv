// ============================================================================
// Módulo: address_decoder
// Proyecto 3 — Control digital RISC-V / Convertidor Boost
// Curso: EL3313 Taller de Diseño Digital
// ============================================================================
// Descripción:
//   Decodificador de direcciones para el bus de datos del microcontrolador
//   RISC-V rv32i. Traduce la dirección de 32 bits proveniente del CPU en
//   señales de selección para el multiplexor de lectura (sel_o[2:0]) y
//   señales de write-enable individuales para cada periférico.
//
// Mapa de memoria implementado:
//   Región          | Rango de direcciones         | sel_o
//   ────────────────|─────────────────────────────-|───────
//   RAM             | 0x0000_2000 – 0x0000_2FFF    | 3'd0
//   UART            | 0x0001_0040 – 0x0001_004F    | 3'd1
//   PWM             | 0x0001_0100 – 0x0001_010F    | 3'd2
//   ADC/XADC        | 0x0001_0110 – 0x0001_011F    | 3'd3
//   VGA             | 0x0001_0120 – 0x0001_012F    | 3'd4
//   GPIO            | 0x0001_0130 – 0x0001_013F    | 3'd5
//   Fuera de rango  | cualquier otra               | 3'd7
// ============================================================================

module address_decoder (
    // ── Entradas desde el CPU ──
    input  logic [31:0] address_i,   // Bus de direcciones del procesador
    input  logic        we_i,        // Write-enable global del CPU

    // ── Señales de selección para el mux de lectura ──
    output logic [2:0]  sel_o,       // {sel2, sel1, sel0}

    // ── Write-enables individuales hacia periféricos ──
    output logic        we_ram_o,
    output logic        we_uart_o,
    output logic        we_pwm_o,
    output logic        we_adc_o,
    output logic        we_vga_o,
    output logic        we_gpio_o
);

    // ========================================================================
    // Parámetros locales — Direcciones base del mapa de memoria
    // ========================================================================
    // Se comparan los bits [31:12] para RAM y [31:4] para periféricos,
    // ya que los bits inferiores seleccionan el registro específico (offset).

    // RAM: 0x0000_2000 – 0x0000_2FFF → address[31:12] == 20'h00002
    localparam logic [19:0] RAM_BASE_HI = 20'h00002;

    // Periféricos: todos comparten address[31:16] == 16'h0001
    // Se distinguen por address[15:4]:
    localparam logic [11:0] UART_ID = 12'h004;   // 0x0001_004x
    localparam logic [11:0] PWM_ID  = 12'h010;   // 0x0001_010x
    localparam logic [11:0] ADC_ID  = 12'h011;   // 0x0001_011x
    localparam logic [11:0] VGA_ID  = 12'h012;   // 0x0001_012x
    localparam logic [11:0] GPIO_ID = 12'h013;   // 0x0001_013x

    // ========================================================================
    // Señales internas de selección (one-hot)
    // ========================================================================
    logic sel_ram;
    logic sel_uart;
    logic sel_pwm;
    logic sel_adc;
    logic sel_vga;
    logic sel_gpio;

    // ========================================================================
    // Lógica de decodificación combinacional
    // ========================================================================
    always_comb begin
        // ── Valores por defecto: nada seleccionado ──
        sel_ram  = 1'b0;
        sel_uart = 1'b0;
        sel_pwm  = 1'b0;
        sel_adc  = 1'b0;
        sel_vga  = 1'b0;
        sel_gpio = 1'b0;
        sel_o    = 3'd7;       // Fuera de rango por defecto

        // ── Decodificación por región ──
        if (address_i[31:12] == RAM_BASE_HI) begin
            // -------- RAM --------
            sel_ram = 1'b1;
            sel_o   = 3'd0;

        end else if (address_i[31:16] == 16'h0001) begin
            // -------- Espacio de periféricos --------
            case (address_i[15:4])
                UART_ID: begin
                    sel_uart = 1'b1;
                    sel_o    = 3'd1;
                end

                PWM_ID: begin
                    sel_pwm = 1'b1;
                    sel_o   = 3'd2;
                end

                ADC_ID: begin
                    sel_adc = 1'b1;
                    sel_o   = 3'd3;
                end

                VGA_ID: begin
                    sel_vga = 1'b1;
                    sel_o   = 3'd4;
                end

                GPIO_ID: begin
                    sel_gpio = 1'b1;
                    sel_o    = 3'd5;
                end

                default: begin
                    // Dirección en espacio de periféricos pero no asignada
                    sel_o = 3'd7;
                end
            endcase

        end else begin
            // -------- Dirección completamente fuera de rango --------
            sel_o = 3'd7;
        end
    end

    // ========================================================================
    // Generación de write-enables individuales
    // ========================================================================
    // Solo se activa el WE del periférico seleccionado cuando el CPU
    // indica escritura (we_i = 1) Y la dirección cae en su rango.

    assign we_ram_o  = we_i & sel_ram;
    assign we_uart_o = we_i & sel_uart;
    assign we_pwm_o  = we_i & sel_pwm;
    assign we_adc_o  = we_i & sel_adc;
    assign we_vga_o  = we_i & sel_vga;
    assign we_gpio_o = we_i & sel_gpio;

endmodule
