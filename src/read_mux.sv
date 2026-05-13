// ============================================================================
// Módulo: read_mux
// Proyecto 3 — Control digital RISC-V / Convertidor Boost
// Curso: EL3313 Taller de Diseño Digital
// ============================================================================
// Descripción:
//   Multiplexor de lectura para el bus de datos del microcontrolador.
//   Selecciona cuál periférico coloca su dato en el bus DataIn_i del CPU
//   según las señales sel[2:0] provenientes del address_decoder.
//
//   sel[2:0]  | Fuente de datos
//   ──────────|────────────────
//   3'd0      | RAM
//   3'd1      | UART
//   3'd2      | PWM
//   3'd3      | ADC/XADC
//   3'd4      | VGA
//   3'd5      | GPIO
//   3'd7      | 0x00000000 (fuera de rango)
// ============================================================================

module read_mux (
    // ── Señal de selección desde el address_decoder ──
    input  logic [2:0]  sel_i,

    // ── Buses de lectura desde cada periférico/memoria ──
    input  logic [31:0] data_ram_i,
    input  logic [31:0] data_uart_i,
    input  logic [31:0] data_pwm_i,
    input  logic [31:0] data_adc_i,
    input  logic [31:0] data_vga_i,
    input  logic [31:0] data_gpio_i,

    // ── Bus de datos hacia el CPU (DataIn_i del procesador) ──
    output logic [31:0] data_out_o
);

    // ========================================================================
    // Lógica de selección combinacional
    // ========================================================================
    always_comb begin
        case (sel_i)
            3'd0:    data_out_o = data_ram_i;
            3'd1:    data_out_o = data_uart_i;
            3'd2:    data_out_o = data_pwm_i;
            3'd3:    data_out_o = data_adc_i;
            3'd4:    data_out_o = data_vga_i;
            3'd5:    data_out_o = data_gpio_i;
            default: data_out_o = 32'h0000_0000;  // Fuera de rango → ceros
        endcase
    end

endmodule
