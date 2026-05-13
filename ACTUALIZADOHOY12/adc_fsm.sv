// =============================================================================
// adc_fsm.sv
//
// Maquina de estados del periferico ADC.
// Solo emite senales de control. No maneja datos.
//
// Estados:
//   S_IDLE       -> esperando un disparo
//   S_START      -> manda pulso CONVST al XADC para arrancar conversion
//   S_WAIT_EOC   -> espera que el XADC termine (EOC=1)
//   S_READ       -> manda transaccion DRP de lectura al XADC
//   S_WAIT_DRDY  -> espera que el XADC entregue el dato (DRDY=1) y captura
//
// NOTA: en el dibujo dijimos 4 estados. En el codigo el estado LEER se
// desdobla en dos (READ + WAIT_DRDY) porque pedir el dato y esperar la
// respuesta son dos pasos distintos del protocolo DRP.
// =============================================================================

`timescale 1ns / 1ps

module adc_fsm (
    input  logic clk_i,
    input  logic rst_i,

    // Disparo combinado (las 3 fuentes ya OR-eadas)
    input  logic trigger_i,

    // Senales de estado del XADC
    input  logic eoc_i,        // End Of Conversion
    input  logic drdy_i,       // DRP Ready

    // Senales de control hacia el XADC
    output logic convst_o,     // Pulso para arrancar conversion
    output logic drp_en_o,     // Habilita transaccion DRP
    output logic drp_we_o,     // Write Enable DRP (siempre 0 = lectura)

    // Senales de control hacia el datapath
    output logic capture_o,    // Capturar el dato del XADC al registro
    output logic set_new_o,    // Prender la bandera new_data
    output logic busy_o        // Indicar que hay conversion en curso
);

    typedef enum logic [2:0] {
        S_IDLE,
        S_START,
        S_WAIT_EOC,
        S_READ,
        S_WAIT_DRDY
    } state_t;

    state_t state, next_state;

    // -------------------------------------------------------------------------
    // Registro de estado
    // -------------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (rst_i) state <= S_IDLE;
        else       state <= next_state;
    end

    // -------------------------------------------------------------------------
    // Logica de proximo estado
    // -------------------------------------------------------------------------
    always_comb begin
        next_state = state;
        unique case (state)
            S_IDLE:      if (trigger_i) next_state = S_START;
            S_START:                    next_state = S_WAIT_EOC;
            S_WAIT_EOC:  if (eoc_i)     next_state = S_READ;
            S_READ:                     next_state = S_WAIT_DRDY;
            S_WAIT_DRDY: if (drdy_i)    next_state = S_IDLE;
            default:                    next_state = S_IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // Salidas combinacionales
    // -------------------------------------------------------------------------
    always_comb begin
        // Defaults: todo apagado
        convst_o  = 1'b0;
        drp_en_o  = 1'b0;
        drp_we_o  = 1'b0;
        capture_o = 1'b0;
        set_new_o = 1'b0;
        busy_o    = 1'b0;

        unique case (state)
            S_IDLE: begin
                // Nada prendido. Esperando trigger.
            end

            S_START: begin
                convst_o = 1'b1;   // Pulso de un ciclo al XADC
                busy_o   = 1'b1;
            end

            S_WAIT_EOC: begin
                busy_o = 1'b1;
            end

            S_READ: begin
                drp_en_o = 1'b1;   // Pulso para iniciar lectura DRP
                drp_we_o = 1'b0;   // 0 = leer (no escribir)
                busy_o   = 1'b1;
            end

            S_WAIT_DRDY: begin
                busy_o = 1'b1;
                if (drdy_i) begin
                    capture_o = 1'b1;   // Capturar dato del XADC
                    set_new_o = 1'b1;   // Prender bandera new_data
                end
            end

            default: ;
        endcase
    end

endmodule