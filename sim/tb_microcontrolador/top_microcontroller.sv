// ============================================================================
// Modulo: top_microcontroller
// Proyecto 3 -- Control digital RISC-V / Convertidor Boost
// Curso: EL3313 Taller de Diseno Digital
// ============================================================================
// [FIX CDC] El VGA ahora corre en clk_cpu (100 MHz) con pixel enable interno.
//   La salida clk_out1 (25 MHz) del PLL ya no se usa para VGA.
//   Si se desea, se puede reconfigurar el PLL para tener solo la salida
//   de 16 MHz (UART) y eliminar la de 25 MHz.
// ============================================================================

module top_microcontroller (
    input  logic        clk_100mhz,
    input  logic        rst_btn,
    output logic        pwm_o,
    input  logic        vauxp6,
    input  logic        vauxn6,
    input  logic        RsRx,
    output logic        RsTx,
    output logic        hsync_o,
    output logic        vsync_o,
    output logic [3:0]  vga_red_o,
    output logic [3:0]  vga_grn_o,
    output logic [3:0]  vga_blu_o,
    input  logic        btn_send
);

    // ========================================================================
    // 1. GENERACION DE RELOJES
    // ========================================================================

    logic clk_cpu;
    logic clk_vga;      // 25 MHz -- ya no se usa para VGA, puede eliminarse del PLL
    logic clk_uart;
    logic pll_locked;

    assign clk_cpu = clk_100mhz;

    clk_wiz_0 pll (
        .clk_in1  (clk_100mhz),
        .clk_out1 (clk_vga),       // 25 MHz (sin uso, se puede quitar del PLL)
        .clk_out2 (clk_uart),      // 16 MHz (UART)
        .reset    (rst_btn),
        .locked   (pll_locked)
    );

    logic rst_sync;
    assign rst_sync = rst_btn | ~pll_locked;

    // ========================================================================
    // 2. SENALES DEL BUS INTERNO
    // ========================================================================

    logic [31:0] ProgAddress;
    logic [31:0] ProgData;
    logic [31:0] DataAddress;
    logic [31:0] DataOut;
    logic [31:0] DataIn;
    logic        we_cpu;

    logic [2:0]  sel;
    logic        we_ram, we_uart, we_pwm, we_adc, we_vga, we_gpio;

    logic [31:0] rdata_ram;
    logic [31:0] rdata_uart;
    logic [31:0] rdata_pwm;
    logic [31:0] rdata_adc;
    logic [31:0] rdata_vga;
    logic [31:0] rdata_gpio;

    logic        pwm_trigger;

    logic        sel_pwm_active;
    assign sel_pwm_active = (sel == 3'd2);

    // ========================================================================
    // 3. PROCESADOR RISC-V rv32i
    // ========================================================================

    cpu u_cpu (
        .clk            (clk_cpu),
        .reset          (rst_sync),
        .ProgAddress_o  (ProgAddress),
        .ProgIn_i       (ProgData),
        .DataAddress_o  (DataAddress),
        .DataOut_o      (DataOut),
        .DataIn_i       (DataIn),
        .we_o           (we_cpu)
    );

    // ========================================================================
    // 4. MEMORIAS
    // ========================================================================

    instruction_memory u_rom (
        .address     (ProgAddress),
        .instruction (ProgData)
    );

    data_memory u_ram (
        .clk    (clk_cpu),
        .reset  (rst_sync),
        .WE     (we_ram),
        .A      (DataAddress),
        .WD     (DataOut),
        .RD     (rdata_ram)
    );

    // ========================================================================
    // 5. INFRAESTRUCTURA DE BUS
    // ========================================================================

    address_decoder u_addr_dec (
        .address_i  (DataAddress),
        .we_i       (we_cpu),
        .sel_o      (sel),
        .we_ram_o   (we_ram),
        .we_uart_o  (we_uart),
        .we_pwm_o   (we_pwm),
        .we_adc_o   (we_adc),
        .we_vga_o   (we_vga),
        .we_gpio_o  (we_gpio)
    );

    read_mux u_read_mux (
        .sel_i       (sel),
        .data_ram_i  (rdata_ram),
        .data_uart_i (rdata_uart),
        .data_pwm_i  (rdata_pwm),
        .data_adc_i  (rdata_adc),
        .data_vga_i  (rdata_vga),
        .data_gpio_i (rdata_gpio),
        .data_out_o  (DataIn)
    );

    // ========================================================================
    // 6. PERIFERICOS
    // ========================================================================

    pwm u_pwm (
        .clk_i          (clk_cpu),
        .rst_i          (rst_sync),
        .sel_i          (sel_pwm_active),
        .we_i           (we_cpu),
        .addr_i         (DataAddress[3:0]),
        .wdata_i        (DataOut),
        .rdata_o        (rdata_pwm),
        .pwm_o          (pwm_o),
        .pwm_trigger_o  (pwm_trigger)
    );

    adc_peripheral u_adc (
        .clk_cpu_i       (clk_cpu),
        .rst_cpu_i       (rst_sync),
        .write_enable_i  (we_adc),
        .addr_i          (DataAddress[3:2]),
        .wdata_i         (DataOut),
        .rdata_o         (rdata_adc),
        .clk_adc_i       (clk_cpu),
        .rst_adc_i       (rst_sync),
        .adc_start_ext_i (1'b0),
        .pwm_trigger_i   (pwm_trigger),
        .vauxp_i         (vauxp6),
        .vauxn_i         (vauxn6)
    );

    uart_peripheral u_uart (
        .clk_cpu_i       (clk_cpu),
        .rst_cpu_i       (rst_sync),
        .write_enable_i  (we_uart),
        .addr_i          (DataAddress[3:2]),
        .wdata_i         (DataOut),
        .rdata_o         (rdata_uart),
        .clk_uart_i      (clk_uart),
        .rst_uart_i      (rst_sync),
        .RsRx            (RsRx),
        .RsTx            (RsTx)
    );

    // [FIX CDC] VGA ahora en clk_cpu (100 MHz) con pixel enable interno
    vga_periph u_vga (
        .clk_i      (clk_cpu),
        .rst_i      (rst_sync),
        .offset_i   (DataAddress[3:0]),
        .wdata_i    (DataOut),
        .we_i       (we_vga),
        .rdata_o    (rdata_vga),
        .hsync_o    (hsync_o),
        .vsync_o    (vsync_o),
        .red_o      (vga_red_o),
        .grn_o      (vga_grn_o),
        .blu_o      (vga_blu_o)
    );

    gpio_peripheral u_gpio (
        .clk_i      (clk_cpu),
        .rst_i      (rst_sync),
        .rdata_o    (rdata_gpio),
        .boton_i    (btn_send)
    );

endmodule