`timescale 1ns / 1ps

module tb_cpu;

    // ── Relojes y reset ──
    logic        clk;
    logic        reset;

    // ── Bus de instrucciones ──
    logic [31:0] ProgAddress;
    logic [31:0] ProgData;

    // ── Bus de datos ──
    logic [31:0] DataAddress;
    logic [31:0] DataOut;
    logic [31:0] DataIn;
    logic        we_cpu;

    // ── Instancia del CPU ──
    cpu uut (
        .clk          (clk),
        .reset        (reset),
        .ProgAddress_o(ProgAddress),
        .ProgIn_i     (ProgData),
        .DataAddress_o(DataAddress),
        .DataOut_o    (DataOut),
        .DataIn_i     (DataIn),
        .we_o         (we_cpu)
    );

    // ── Memoria de instrucciones (ROM) ──
    instruction_memory u_rom (
        .address    (ProgAddress),
        .instruction(ProgData)
    );

    // ── Memoria de datos (RAM 0x2000-0x2FFF) ──
    logic        we_ram;
    logic [31:0] rdata_ram;

    assign we_ram = we_cpu && (DataAddress[31:12] == 20'h00002);

    data_memory u_ram (
        .clk   (clk),
        .reset (reset),
        .WE    (we_ram),
        .A     (DataAddress),
        .WD    (DataOut),
        .RD    (rdata_ram)
    );

    logic [31:0] rdata_periph;

    always_comb begin
        rdata_periph = 32'h0;
        if (DataAddress[31:16] == 16'h0001) begin
            case (DataAddress[15:4])
                12'h004: begin  // UART (0x040-0x04F)
                    // UART_CTRL (offset 0x00 → addr_i=00): tx_busy=bit2=0
                    rdata_periph = 32'h0000_0000;
                end
                12'h011: begin  // ADC (0x110-0x11F)
                    if (DataAddress[3:2] == 2'b00)
                        rdata_periph = 32'h0000_0002; // new_data=1 (bit 1)
                    else
                        rdata_periph = 32'h0000_0800; // ADC value = 2048
                end
                12'h013: begin  // GPIO (0x130-0x13F)
                    rdata_periph = 32'h0000_0001;     // boton presionado
                end
                default: rdata_periph = 32'h0;
            endcase
        end
    end

    // ── Mux de lectura (simplificado) ──
    always_comb begin
        if (DataAddress[31:12] == 20'h00002)
            DataIn = rdata_ram;
        else
            DataIn = rdata_periph;
    end

    always_ff @(posedge clk) begin
        if (!reset && we_cpu) begin
            case (DataAddress)
                32'h0001_0100: $display("[%7t ns] PWM_CTRL  <= 0x%08h", $time, DataOut);
                32'h0001_0104: $display("[%7t ns] PWM_DUTY  <= %3d%%",   $time, DataOut);
                32'h0001_0110: $display("[%7t ns] ADC_CTRL  <= 0x%08h", $time, DataOut);
                32'h0001_0120: $display("[%7t ns] VGA_CTRL  <= 0x%08h", $time, DataOut);
                32'h0001_0124: $display("[%7t ns] VGA_DATA  <= %4d",     $time, DataOut);
                32'h0001_0040: $display("[%7t ns] UART_CTRL <= 0x%08h", $time, DataOut);
                32'h0001_0044: $display("[%7t ns] UART_TX   <= '%c' (0x%02h)", $time, DataOut[7:0], DataOut[7:0]);
                default: ;
            endcase
        end
    end

    // ── Generador de reloj 100 MHz ──
    initial clk = 0;
    always  #5 clk = ~clk;

    // ── Secuencia principal ──
    initial begin
        $dumpfile("tb_cpu_proyecto3.vcd");
        $dumpvars(0, tb_cpu);

        reset = 1;
        $display("=== Inicio simulacion CPU Proyecto 3 ===");
        $display("    ADC mock: new_data=1, value=2048");
        $display("    GPIO mock: boton siempre presionado");
        $display("    UART mock: tx_busy=0 (sin espera)");
        $display("============================================");

        #30;
        reset = 0;
        $display("[%7t ns] Reset liberado. CPU corriendo.", $time);

        // Dejar correr suficiente para ver inicializacion + 1 envio UART
        // Con mock de perifericos rapidos, el ciclo completo toma ~500 ciclos
        #10000;

        $display("============================================");
        $display("    Simulacion finalizada.");
        $finish;
    end

    // ── Monitor de PC y WB cada ciclo negativo ──
    always_ff @(negedge clk) begin
        if (!reset)
            $display("[%7t ns] PC=0x%08h  DataAddr=0x%08h  DataIn=0x%08h  we=%b",
                     $time, ProgAddress, DataAddress, DataIn, we_cpu);
    end

endmodule