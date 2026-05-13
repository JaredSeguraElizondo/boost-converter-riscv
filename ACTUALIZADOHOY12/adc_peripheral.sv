// =============================================================================
// adc_peripheral.sv
//
// Periferico ADC mapeado en memoria del microcontrolador RISC-V.
//
//   Registro Control/Estado en offset 0x00 (direccion 0x0001_0110)
//     bit 0: start         (W1P)   - arranca conversion por software
//     bit 1: new_data      (RW1C)  - dato nuevo disponible
//     bit 2: ext_start_en  (R/W)   - habilita disparo externo
//     bit 3: busy          (RO)    - conversion en curso
//     bit 4: pwm_trig_en   (R/W)   - habilita disparo por PWM
//
//   Registro Dato en offset 0x04 (direccion 0x0001_0114)
//     bits [11:0]: adc_data (RO)
//
// Canal del XADC: hardcodeado a VAUX6 (channel address 0x16).
// Si se cambia el canal, hay que ajustar:
//   1. INIT_40 del XADC (los 6 bits bajos)
//   2. DADDR del XADC
//   3. La asignacion VAUXP/VAUXN (mover el bit 6 a la posicion correcta)
//
// Dependencias:
//   - adc_fsm.sv (maquina de estados de control)
// =============================================================================

`timescale 1ns / 1ps

module adc_peripheral (
    // Interfaz del bus (lado CPU)
    input  logic        clk_cpu_i,
    input  logic        rst_cpu_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    // Reloj para el XADC
    input  logic        clk_adc_i,
    input  logic        rst_adc_i,

    // Disparos externos
    input  logic        adc_start_ext_i,
    input  logic        pwm_trigger_i,

    // Pines analogicos (par diferencial de la JXADC, canal VAUX6)
    input  logic        vauxp_i,
    input  logic        vauxn_i
);

    // =========================================================================
    // 1. REGISTROS DEL BUS (DOMINIO CPU)
    // =========================================================================

    logic        reg_start;
    logic        reg_new_data;
    logic        reg_ext_start_en;
    logic        reg_pwm_trig_en;
    logic [11:0] reg_adc_data;

    // =========================================================================
    // 2. SENALES INTERNAS
    // =========================================================================

    // FSM <-> XADC
    logic        fsm_convst;
    logic        fsm_drp_en;
    logic        fsm_drp_we;
    logic        fsm_capture;
    logic        fsm_set_new;
    logic        fsm_busy;

    logic        xadc_eoc;
    logic        xadc_drdy;
    logic [15:0] xadc_do;

    // Trigger combinado (en dominio clk_adc_i)
    logic        trigger_combined;
    logic        start_pulse_adc;
    logic        ext_pulse_adc;
    logic        pwm_pulse_adc;

    // Pulsos sincronizados al dominio CPU
    logic        capture_pulse_cpu;
    logic        set_new_pulse_cpu;

    // =========================================================================
    // 3. CRUCE DE DOMINIOS: CPU -> ADC
    // =========================================================================

    // 3.1 Sincronizar reg_start al dominio ADC y detectar flanco de subida
    logic [2:0] sync_start;
    always_ff @(posedge clk_adc_i) begin
        if (rst_adc_i) sync_start <= 3'b000;
        else           sync_start <= {sync_start[1:0], reg_start};
    end
    assign start_pulse_adc = sync_start[1] & ~sync_start[2];

    // 3.2 Sincronizar adc_start_ext_i y detectar flanco
    logic [2:0] sync_ext;
    always_ff @(posedge clk_adc_i) begin
        if (rst_adc_i) sync_ext <= 3'b000;
        else           sync_ext <= {sync_ext[1:0], adc_start_ext_i};
    end
    assign ext_pulse_adc = sync_ext[1] & ~sync_ext[2];

    // 3.3 Sincronizar pwm_trigger_i y detectar flanco
    logic [2:0] sync_pwm;
    always_ff @(posedge clk_adc_i) begin
        if (rst_adc_i) sync_pwm <= 3'b000;
        else           sync_pwm <= {sync_pwm[1:0], pwm_trigger_i};
    end
    assign pwm_pulse_adc = sync_pwm[1] & ~sync_pwm[2];

    // 3.4 Sincronizar los enables al dominio ADC (nivel)
    logic [1:0] sync_ext_en;
    logic [1:0] sync_pwm_en;
    always_ff @(posedge clk_adc_i) begin
        if (rst_adc_i) begin
            sync_ext_en <= 2'b00;
            sync_pwm_en <= 2'b00;
        end else begin
            sync_ext_en <= {sync_ext_en[0], reg_ext_start_en};
            sync_pwm_en <= {sync_pwm_en[0], reg_pwm_trig_en};
        end
    end

    // =========================================================================
    // 4. COMBINADOR DE DISPAROS
    //    Las 3 fuentes (software, externa, PWM) se combinan con OR.
    //    Las externas estan condicionadas por sus bits de habilitacion.
    // =========================================================================

    assign trigger_combined = start_pulse_adc
                            | (ext_pulse_adc & sync_ext_en[1])
                            | (pwm_pulse_adc & sync_pwm_en[1]);

    // =========================================================================
    // 5. INSTANCIA DE LA FSM
    // =========================================================================

    adc_fsm fsm_inst (
        .clk_i     (clk_adc_i),
        .rst_i     (rst_adc_i),
        .trigger_i (trigger_combined),
        .eoc_i     (xadc_eoc),
        .drdy_i    (xadc_drdy),
        .convst_o  (fsm_convst),
        .drp_en_o  (fsm_drp_en),
        .drp_we_o  (fsm_drp_we),
        .capture_o (fsm_capture),
        .set_new_o (fsm_set_new),
        .busy_o    (fsm_busy)
    );

    // =========================================================================
    // 6. INSTANCIA DEL XADC (primitivo de Xilinx para Artix-7)
    //    Configuracion: single channel, event-driven, canal VAUX6 (0x16)
    //    Los valores INIT estan basados en UG480; verificar para ajustes finos.
    // =========================================================================

    XADC #(
        .INIT_40(16'h0216),    // CONFIG0: event-driven, unipolar, canal VAUX6
        .INIT_41(16'h30F0),    // CONFIG1: single channel mode, alarmas off
        .INIT_42(16'h0400),    // CONFIG2: divisor DCLK = 4
        .SIM_DEVICE("7SERIES"),
        .SIM_MONITOR_FILE("design.txt")
    ) xadc_inst (
        .CONVST       (fsm_convst),
        .CONVSTCLK    (1'b0),
        .RESET        (rst_adc_i),

        .VAUXP        ({9'b0, vauxp_i, 6'b0}),
        .VAUXN        ({9'b0, vauxn_i, 6'b0}),
        .VP           (1'b0),
        .VN           (1'b0),

        .DADDR        (7'h16),
        .DCLK         (clk_adc_i),
        .DEN          (fsm_drp_en),
        .DI           (16'h0000),
        .DWE          (fsm_drp_we),
        .DO           (xadc_do),
        .DRDY         (xadc_drdy),

        .EOC          (xadc_eoc),
        .EOS          (),
        .BUSY         (),
        .CHANNEL      (),
        .OT           (),
        .ALM          (),

        .JTAGBUSY     (),
        .JTAGLOCKED   (),
        .JTAGMODBIT   ()
    );

    // =========================================================================
    // 7. CAPTURA DEL DATO Y CRUCE DE DOMINIOS: ADC -> CPU
    // =========================================================================

    // 7.1 Capturar el dato en dominio ADC cuando la FSM lo indica.
    //     El XADC entrega el resultado en xadc_do[15:4] (12 bits altos).
    logic [11:0] adc_data_in_adc_clk;
    always_ff @(posedge clk_adc_i) begin
        if (rst_adc_i)        adc_data_in_adc_clk <= 12'h000;
        else if (fsm_capture) adc_data_in_adc_clk <= xadc_do[15:4];
    end

    // 7.2 Sincronizar pulso de captura al dominio CPU
    logic [2:0] sync_capture;
    always_ff @(posedge clk_cpu_i) begin
        if (rst_cpu_i) sync_capture <= 3'b000;
        else           sync_capture <= {sync_capture[1:0], fsm_capture};
    end
    assign capture_pulse_cpu = sync_capture[1] & ~sync_capture[2];

    // 7.3 Sincronizar pulso de set_new al dominio CPU
    logic [2:0] sync_set_new;
    always_ff @(posedge clk_cpu_i) begin
        if (rst_cpu_i) sync_set_new <= 3'b000;
        else           sync_set_new <= {sync_set_new[1:0], fsm_set_new};
    end
    assign set_new_pulse_cpu = sync_set_new[1] & ~sync_set_new[2];

    // 7.4 Sincronizar busy al dominio CPU (nivel)
    logic [2:0] sync_busy;
    logic       busy_in_cpu;
    always_ff @(posedge clk_cpu_i) begin
        if (rst_cpu_i) sync_busy <= 3'b000;
        else           sync_busy <= {sync_busy[1:0], fsm_busy};
    end
    assign busy_in_cpu = sync_busy[2];

    // 7.5 Latch del dato en dominio CPU (cuando llega el pulso de captura)
    always_ff @(posedge clk_cpu_i) begin
        if (rst_cpu_i)              reg_adc_data <= 12'h000;
        else if (capture_pulse_cpu) reg_adc_data <= adc_data_in_adc_clk;
    end

    // =========================================================================
    // 8. LOGICA DE LOS REGISTROS DEL BUS (DOMINIO CPU)
    // =========================================================================

    always_ff @(posedge clk_cpu_i) begin
        if (rst_cpu_i) begin
            reg_start        <= 1'b0;
            reg_new_data     <= 1'b0;
            reg_ext_start_en <= 1'b0;
            reg_pwm_trig_en  <= 1'b0;
        end else begin
            // Escrituras del bus
            if (write_enable_i) begin
                case (addr_i)
                    2'b00: begin
                        if (wdata_i[0]) reg_start    <= 1'b1;   // bit 0 W1P
                        if (wdata_i[1]) reg_new_data <= 1'b0;   // bit 1 RW1C
                        reg_ext_start_en <= wdata_i[2];         // bit 2 R/W
                        reg_pwm_trig_en  <= wdata_i[4];         // bit 4 R/W
                    end
                    default: ;  // 0x04 es solo lectura
                endcase
            end

            // Auto-clear de reg_start cuando la FSM ya empezo
            if (busy_in_cpu) reg_start <= 1'b0;

            // Set de new_data desde la FSM (ultimo, gana sobre RW1C
            // en caso muy improbable de coincidencia)
            if (set_new_pulse_cpu) reg_new_data <= 1'b1;
        end
    end

    // =========================================================================
    // 9. MUX DE LECTURA
    // =========================================================================

    always_comb begin
        unique case (addr_i)
            2'b00:   rdata_o = {27'd0,
                                reg_pwm_trig_en,    // bit 4
                                busy_in_cpu,        // bit 3
                                reg_ext_start_en,   // bit 2
                                reg_new_data,       // bit 1
                                reg_start};         // bit 0
            2'b01:   rdata_o = {20'd0, reg_adc_data};
            default: rdata_o = 32'h0;
        endcase
    end

endmodule