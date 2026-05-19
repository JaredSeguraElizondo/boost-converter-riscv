`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/30/2026 04:35:28 PM
// Design Name: 
// Module Name: XADC
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module adc_xadc_mmio (
    input  logic        clk,
    input  logic        rst,
    
    // Interfaz MMIO (Conexión con el RISC-V)
    input  logic        we_i,
    input  logic [3:0]  addr_i,
    input  logic [31:0] dat_i,
    output logic [31:0] dat_o,
    
    // Entradas de disparo (Triggers)
    input  logic        pwm_trigger_i,
    input  logic        adc_start_ext_i,
    
    // Interfaz DRP hacia el IP XADC (Nombres y anchos exactos de tu TOP.sv)
    output logic        convst_o,
    input  logic        eoc_i,
    input  logic        drdy_i,
    input  logic [15:0] do_i,
    output logic [6:0]  daddr_o,
    output logic        den_o,
    output logic        dwe_o,
    output logic [15:0] di_o
);

    // =========================================================================
    // 1. Registros de Control y Estado
    // =========================================================================
    logic        start_pulse;    // Bit 0
    logic        new_data;       // Bit 1
    logic        ext_start_en;   // Bit 2
    logic        busy;           // Bit 3
    logic        pwm_trig_en;    // Bit 4
    logic [11:0] adc_data;       // Dato resultante

    // Enrutador del disparo de conversión (CONVST)
    assign convst_o = start_pulse | (ext_start_en & adc_start_ext_i) | (pwm_trig_en & pwm_trigger_i);

    // Escritura MMIO
    always_ff @(posedge clk) begin
        if (rst) begin
            start_pulse  <= 1'b0;
            ext_start_en <= 1'b0;
            pwm_trig_en  <= 1'b0;
            new_data     <= 1'b0;
        end else begin
            start_pulse <= 1'b0; // Por defecto es un pulso de 1 ciclo

            if (we_i && addr_i == 4'h0) begin
                if (dat_i[0]) start_pulse <= 1'b1;
                ext_start_en <= dat_i[2];
                pwm_trig_en  <= dat_i[4];
                // RW1C: Limpiar new_data si se escribe un 1
                if (dat_i[1]) new_data <= 1'b0;
            end

            // Limpieza automática al leer el registro de datos
            if (!we_i && addr_i == 4'h4) begin
                new_data <= 1'b0;
            end

            // La máquina de estados levanta esta bandera cuando el dato está listo
            if (drdy_i) begin
                new_data <= 1'b1;
            end
        end
    end

    // Lectura MMIO
    always_comb begin
        dat_o = 32'd0;
        if (addr_i == 4'h0) begin
            // Ensamblaje del Offset 0x00
            dat_o = {27'd0, pwm_trig_en, busy, ext_start_en, new_data, 1'b0};
        end else if (addr_i == 4'h4) begin
            // Ensamblaje del Offset 0x04
            dat_o = {20'd0, adc_data};
        end
    end

    // =========================================================================
    // 2. Máquina de Estados para leer el puerto DRP
    // =========================================================================
    typedef enum logic [1:0] {IDLE, READ_DRP, WAIT_DRDY} state_t;
    state_t state;

    // Configuración estática del puerto DRP para lectura
    assign daddr_o = 7'h16; // VAUX6 (J3/K3 de la Basys 3)
    assign dwe_o   = 1'b0;  // Solo lectura

    always_ff @(posedge clk) begin
        if (rst) begin
            state    <= IDLE;
            den_o    <= 1'b0;
            busy     <= 1'b0;
            adc_data <= 12'd0;
        end else begin
            den_o <= 1'b0; // El Enable del DRP es un pulso

            // Si se dispara la conversión, reportar ocupado
            if (convst_o) busy <= 1'b1;

            case (state)
                IDLE: begin
                    // Esperar a que el XADC termine la conversión (End Of Conversion)
                    if (eoc_i) begin
                        state <= READ_DRP;
                    end
                end
                
                READ_DRP: begin
                    // Enviar solicitud de lectura al puerto DRP
                    den_o <= 1'b1;
                    state <= WAIT_DRDY;
                end
                
                WAIT_DRDY: begin
                    // Esperar a que el DRP entregue el dato (Data Ready)
                    if (drdy_i) begin
                        // El XADC entrega el dato alineado a la izquierda, tomamos los 12 MSB
                        adc_data <= do_i[15:4]; 
                        busy     <= 1'b0;
                        state    <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule