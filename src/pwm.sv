// =============================================================================
// pwm.sv
// -----------------------------------------------------------------------------
// Periferico PWM para microcontrolador RISC-V (Proyecto 3, EL3313 / EL4201).
//
// Mapa de registros (mapeado en memoria a partir de 0x0001_0100):
//   offset 0x00  Control/Estado:
//                  bit 0       enable    (R/W)
//                  bits[2:1]   freq_sel  (R/W)  00=25kHz, 01=50kHz, 10=100kHz
//                  bit 3       running   (RO)
//                  bits[31:4]  reservados
//   offset 0x04  Duty cycle:
//                  bits[6:0]   duty_pct  (R/W)  0..100, satura fuera de rango
//                  bits[31:7]  reservados
//
// Genera onda triangular con un contador up/down. La salida pwm_o esta alta
// mientras counter < duty_count. pwm_trigger_o pulsa un ciclo en el valle.
//
// Compatible con Vivado XSim/Synth: evita bit-select sobre expresiones
// y sobre elementos indexados de arreglos.


module pwm #(
    parameter int CLK_FREQ_HZ = 100_000_000
) (
    input  logic        clk_i,
    input  logic        rst_i,

    // Interfaz al bus de datos del microcontrolador
    input  logic        sel_i,
    input  logic        we_i,
    input  logic [3:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    // Salidas hacia hardware externo
    output logic        pwm_o,
    output logic        pwm_trigger_o
);

    // -------------------------------------------------------------------------
    // Calculo de constantes en tiempo de elaboracion (no genera HW)
    // -------------------------------------------------------------------------
    localparam int MAX_25K_VAL   = CLK_FREQ_HZ / (2 * 25_000);    // 2000
    localparam int MAX_50K_VAL   = CLK_FREQ_HZ / (2 * 50_000);    // 1000
    localparam int MAX_100K_VAL  = CLK_FREQ_HZ / (2 * 100_000);   //  500
    localparam int STEP_25K_VAL  = MAX_25K_VAL  / 100;            // 20
    localparam int STEP_50K_VAL  = MAX_50K_VAL  / 100;            // 10
    localparam int STEP_100K_VAL = MAX_100K_VAL / 100;            //  5

    // Ancho del contador: alcanza para el MAX mas grande (25 kHz)
    localparam int CNT_W = $clog2(MAX_25K_VAL + 1);

    // Versiones tipadas (truncacion implicita desde int, totalmente sintetizable)
    localparam logic [CNT_W-1:0] MAX_25K   = MAX_25K_VAL;
    localparam logic [CNT_W-1:0] MAX_50K   = MAX_50K_VAL;
    localparam logic [CNT_W-1:0] MAX_100K  = MAX_100K_VAL;
    localparam logic [4:0]       STEP_25K  = STEP_25K_VAL;
    localparam logic [4:0]       STEP_50K  = STEP_50K_VAL;
    localparam logic [4:0]       STEP_100K = STEP_100K_VAL;

    localparam logic [3:0] ADDR_CTRL = 4'h0;
    localparam logic [3:0] ADDR_DUTY = 4'h4;

    typedef enum logic {UP, DOWN} dir_t;

    // -------------------------------------------------------------------------
    // Registros expuestos al bus
    // -------------------------------------------------------------------------
    logic       ctrl_enable;
    logic [1:0] ctrl_freq_sel;
    logic [6:0] duty_pct_reg;

    // -------------------------------------------------------------------------
    // Registros activos (sincronizados al valle, doble buffer)
    // -------------------------------------------------------------------------
    logic             active_enable;
    logic [CNT_W-1:0] active_max;
    logic [CNT_W-1:0] active_duty_count;

    // -------------------------------------------------------------------------
    // Contador up/down
    // -------------------------------------------------------------------------
    logic [CNT_W-1:0] counter;
    dir_t             direction;

    logic at_period_start;
    assign at_period_start = (counter == '0) && (direction == UP);

    // -------------------------------------------------------------------------
    // Mux de frecuencias y duty target. Se calcula combinacionalmente a
    // partir de los registros del CPU; recien se aplica al contador en
    // el siguiente valle (doble buffer).
    // -------------------------------------------------------------------------
    logic [CNT_W-1:0] target_max;
    logic [CNT_W-1:0] target_duty_count;

    always_comb begin
        unique case (ctrl_freq_sel)
            2'b00: begin
                target_max        = MAX_25K;
                target_duty_count = duty_pct_reg * STEP_25K;
            end
            2'b01: begin
                target_max        = MAX_50K;
                target_duty_count = duty_pct_reg * STEP_50K;
            end
            2'b10: begin
                target_max        = MAX_100K;
                target_duty_count = duty_pct_reg * STEP_100K;
            end
            default: begin
                target_max        = MAX_50K;
                target_duty_count = duty_pct_reg * STEP_50K;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Escritura de registros desde el bus
    // -------------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            ctrl_enable   <= 1'b0;
            ctrl_freq_sel <= 2'b01;     // default: 50 kHz
            duty_pct_reg  <= 7'd0;
        end else if (sel_i && we_i) begin
            unique case (addr_i)
                ADDR_CTRL: begin
                    ctrl_enable   <= wdata_i[0];
                    ctrl_freq_sel <= wdata_i[2:1];
                end
                ADDR_DUTY: begin
                    if (wdata_i > 32'd100)
                        duty_pct_reg <= 7'd100;
                    else
                        duty_pct_reg <= wdata_i[6:0];
                end
                default: ;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Lectura de registros hacia el bus
    // -------------------------------------------------------------------------
    always_comb begin
        rdata_o = 32'd0;
        if (sel_i && !we_i) begin
            unique case (addr_i)
                ADDR_CTRL:
                    rdata_o = {28'd0, active_enable, ctrl_freq_sel, ctrl_enable};
                ADDR_DUTY:
                    rdata_o = {25'd0, duty_pct_reg};
                default:
                    rdata_o = 32'd0;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Doble buffer: configuraciones se aplican al inicio del valle.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            active_enable     <= 1'b0;
            active_max        <= MAX_50K;
            active_duty_count <= '0;
        end else if (at_period_start) begin
            active_enable     <= ctrl_enable;
            active_max        <= target_max;
            active_duty_count <= target_duty_count;
        end
    end

    // -------------------------------------------------------------------------
    // FSM del contador up/down. El cambio de direccion se decide ANTES de
    // tocar el extremo, asi se evita underflow y se da un solo ciclo en el pico.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (rst_i || !active_enable) begin
            counter   <= '0;
            direction <= UP;
        end else begin
            unique case (direction)
                UP: begin
                    if (counter == active_max - 1) begin
                        counter   <= active_max;
                        direction <= DOWN;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                DOWN: begin
                    if (counter == 1) begin
                        counter   <= '0;
                        direction <= UP;
                    end else begin
                        counter <= counter - 1;
                    end
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Salidas
    // -------------------------------------------------------------------------
    always_comb begin
        if (!active_enable || active_duty_count == '0)
            pwm_o = 1'b0;                              // 0% o apagado
        else if (active_duty_count >= active_max)
            pwm_o = 1'b1;                              // 100%
        else
            pwm_o = (counter < active_duty_count);
    end

    assign pwm_trigger_o = at_period_start && active_enable;

endmodule