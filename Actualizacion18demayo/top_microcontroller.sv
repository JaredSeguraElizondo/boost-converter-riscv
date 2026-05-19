// top_microcontroller.sv  -  Proyecto 3 (reset sincronizado)
// ============================================================================
// VGA con puertos viejos (clk_100mhz, rst, clk_25mhz).
// Reset SINCRONIZADO al clk_cpu via pipeline de 3 etapas para evitar
// problemas de placement por fanout alto del reset asincrono.
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
    input  logic        btn_send,
    output logic [15:0] led
);

    // ========================================================================
    // RELOJES
    // ========================================================================
    logic clk_cpu;
    logic clk_vga;
    logic clk_uart;
    logic pll_locked;

    assign clk_cpu = clk_100mhz;

    clk_wiz_0 pll (
        .clk_in1  (clk_100mhz),
        .clk_out1 (clk_vga),
        .clk_out2 (clk_uart),
        .reset    (rst_btn),
        .locked   (pll_locked)
    );

    // ========================================================================
    // RESET SINCRONIZADO (pipeline de 3 etapas + ASYNC_REG)
    // Esto evita que Vivado intente meter el reset por una BUFG y
    // resuelve problemas de placement por high fanout.
    // ========================================================================
    (* ASYNC_REG = "TRUE" *) logic [2:0] rst_sync_pipe;
    always_ff @(posedge clk_cpu) begin
        rst_sync_pipe <= {rst_sync_pipe[1:0], rst_btn};
    end

    logic rst_sync;
    assign rst_sync = rst_sync_pipe[2];

    // ========================================================================
    // BUS
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
    // LEDs - captura ADC al escribir VGA_VOLT (offset 0x8)
    // ========================================================================
    logic [11:0] adc_for_leds;
    always_ff @(posedge clk_cpu) begin
        if (rst_sync)
            adc_for_leds <= 12'd0;
        else if (we_vga && DataAddress[3:0] == 4'h8)
            adc_for_leds <= DataOut[11:0];
    end

    assign led[11:0]  = adc_for_leds;
    assign led[15:12] = 4'b0;

    // ========================================================================
    // CPU
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
    // MEMORIAS
    // ========================================================================
    instruction_memory u_rom (
        .address     (ProgAddress),
        .instruction (ProgData)
    );

    data_memory u_ram (
        .clk   (clk_cpu),
        .reset (rst_sync),
        .WE    (we_ram),
        .A     (DataAddress),
        .WD    (DataOut),
        .RD    (rdata_ram)
    );

    // ========================================================================
    // BUS
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
    // PERIFERICOS
    // ========================================================================

    pwm u_pwm (
        .clk_i         (clk_cpu),
        .rst_i         (rst_sync),
        .sel_i         (sel_pwm_active),
        .we_i          (we_cpu),
        .addr_i        (DataAddress[3:0]),
        .wdata_i       (DataOut),
        .rdata_o       (rdata_pwm),
        .pwm_o         (pwm_o),
        .pwm_trigger_o (pwm_trigger)
    );

    // ----- ADC: XADC primitivo + adc_xadc_mmio -----
    logic        xadc_convst;
    logic        xadc_eoc;
    logic        xadc_drdy;
    logic [15:0] xadc_do;
    logic [6:0]  xadc_daddr;
    logic        xadc_den;
    logic        xadc_dwe;
    logic [15:0] xadc_di;

    XADC #(
        .INIT_40(16'h0016),
        .INIT_41(16'h3000),
        .INIT_42(16'h0040),
        .INIT_48(16'h0000),
        .INIT_49(16'h0000),
        .INIT_4A(16'h0000),
        .INIT_4B(16'h0000),
        .INIT_4C(16'h0000),
        .INIT_4D(16'h0040),
        .INIT_4E(16'h0000),
        .INIT_4F(16'h0000),
        .SIM_MONITOR_FILE(""),
        .IS_CONVSTCLK_INVERTED(1'b0),
        .IS_DCLK_INVERTED(1'b0)
    ) xadc_raw (
        .DCLK       (clk_cpu),
        .RESET      (rst_sync),
        .DEN        (xadc_den),
        .DADDR      (xadc_daddr),
        .DWE        (xadc_dwe),
        .DI         (xadc_di),
        .DO         (xadc_do),
        .DRDY       (xadc_drdy),
        .EOC        (xadc_eoc),
        .EOS        (),
        .BUSY       (),
        .CHANNEL    (),
        .ALM        (),
        .OT         (),
        .JTAGBUSY   (),
        .JTAGLOCKED (),
        .JTAGMODIFIED(),
        .MUXADDR    (),
        .CONVST     (xadc_convst),
        .CONVSTCLK  (1'b0),
        .VP         (1'b0),
        .VN         (1'b0),
        .VAUXP      ({9'b0, vauxp6, 6'b0}),
        .VAUXN      ({9'b0, vauxn6, 6'b0})
    );

    adc_xadc_mmio u_adc (
        .clk             (clk_cpu),
        .rst             (rst_sync),
        .we_i            (we_adc),
        .addr_i          (DataAddress[3:0]),
        .dat_i           (DataOut),
        .dat_o           (rdata_adc),
        .pwm_trigger_i   (pwm_trigger),
        .adc_start_ext_i (1'b0),
        .convst_o        (xadc_convst),
        .eoc_i           (xadc_eoc),
        .drdy_i          (xadc_drdy),
        .do_i            (xadc_do),
        .daddr_o         (xadc_daddr),
        .den_o           (xadc_den),
        .dwe_o           (xadc_dwe),
        .di_o            (xadc_di)
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

    // ----- VGA con puertos VIEJOS -----
    vga_mmio_wrapper u_vga (
        .clk_100mhz (clk_cpu),
        .rst        (rst_sync),
        .we_i       (we_vga),
        .addr_i     (DataAddress[3:0]),
        .dat_i      (DataOut),
        .dat_o      (rdata_vga),
        .clk_25mhz  (clk_vga),
        .vga_hsync  (hsync_o),
        .vga_vsync  (vsync_o),
        .vga_r      (vga_red_o),
        .vga_g      (vga_grn_o),
        .vga_b      (vga_blu_o)
    );

    gpio_peripheral u_gpio (
        .clk_i   (clk_cpu),
        .rst_i   (rst_sync),
        .rdata_o (rdata_gpio),
        .boton_i (btn_send)
    );

endmodule