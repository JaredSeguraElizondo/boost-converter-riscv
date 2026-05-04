// ============================================================================
// Testbench: tb_vga_visual
// Para comprobar el funcionamiento tanto del pixel azul como del verde

`timescale 1ns / 1ps

module tb_vga_visual;

    // ── Parametros ───────────────────────────────────────────────────────────
    localparam int CLK_PERIOD   = 40;      // ns (25 MHz)
    localparam int H_TOTAL      = 800;
    localparam int H_VISIBLE    = 640;
    localparam int V_TOTAL      = 525;
    localparam int V_VISIBLE    = 480;

    // Muestra a graficar: adc=2048 → Y = 479 - (2048*480>>12) = 479-240 = 239
    localparam int ADC_VALUE    = 12'h800;  // 2048, mitad de escala
    localparam int Y_EXPECTED   = 239;      // fila donde debe aparecer el verde

    // Ciclos desde negedge vsync hasta inicio de la linea verde
    // (535-490)*800 + 239*800 = 28000 + 191200 = 219200 ciclos
    localparam int CYCLES_TO_GREEN = (V_TOTAL - 490) * H_TOTAL
                                   + Y_EXPECTED * H_TOTAL;

    // ── Senales del DUT ──────────────────────────────────────────────────────
    logic        clk;
    logic        rst;
    logic [3:0]  offset;
    logic [31:0] wdata;
    logic        we;
    logic [31:0] rdata;
    logic        hsync;
    logic        vsync;
    logic [3:0]  red;
    logic [3:0]  grn;
    logic [3:0]  blu;

    // ── DUT ──────────────────────────────────────────────────────────────────
    vga_periph dut (
        .clk_i    (clk),
        .rst_i    (rst),
        .offset_i (offset),
        .wdata_i  (wdata),
        .we_i     (we),
        .rdata_o  (rdata),
        .hsync_o  (hsync),
        .vsync_o  (vsync),
        .red_o    (red),
        .grn_o    (grn),
        .blu_o    (blu)
    );

    // ── Reloj ────────────────────────────────────────────────────────────────
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ── Contadores de resultado ──────────────────────────────────────────────
    int pass_count = 0;
    int fail_count = 0;

    task automatic check_cond(input string name, input logic cond);
        if (cond) begin
            $display("  PASS [%s]", name);
            pass_count++;
        end else begin
            $display("  FAIL [%s]", name);
            fail_count++;
        end
    endtask

    // ── Escritura al bus ─────────────────────────────────────────────────────
    task automatic bus_write(input logic [3:0] off, input logic [31:0] data);
        @(posedge clk); #1;
        offset <= off;
        wdata  <= data;
        we     <= 1'b1;
        @(posedge clk); #1;
        we     <= 1'b0;
    endtask

    // ── Secuencia principal ──────────────────────────────────────────────────
    initial begin
        rst    = 1'b1;
        we     = 1'b0;
        offset = 4'h0;
        wdata  = 32'h0;

        $display("============================================");
        $display(" TB VISUAL: vga_periph");
        $display("============================================");
        $display(" Patron esperado:");
        $display("   blu[3:0] alterna entre 2 y 0 (fondo/blanking)");
        $display("   grn[3:0] sube a F por 25,600 ns en la fila %0d", Y_EXPECTED);
        $display("   red[3:0] siempre en 0");
        $display("============================================");

        repeat (5) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        // ── Habilitar VGA ────────────────────────────────────────────────────
        bus_write(4'h0, 32'h1);
        $display("\n[1] VGA habilitado");

        // ── Llenar todo el frame buffer con adc=2048 → fila 239 ──────────────
        // 640 escrituras consecutivas llenan todos los slots del buffer circular
        $display("[2] Escribiendo 640 muestras (adc=%0d → fila %0d)...",
                 ADC_VALUE, Y_EXPECTED);
        for (int i = 0; i < H_VISIBLE; i++) begin
            bus_write(4'h4, 32'(ADC_VALUE));
        end
        $display("    Buffer lleno. grn=F aparecera en fila %0d por 25,600 ns.",
                 Y_EXPECTED);

        // ── Esperar negedge vsync y calcular tiempo exacto del verde ─────────
        $display("[3] Esperando negedge vsync...");
        @(negedge vsync);
        begin
            longint t_vsync    = $time;
            longint t_green    = t_vsync + CYCLES_TO_GREEN * CLK_PERIOD;
            longint t_green_end = t_green + H_VISIBLE * CLK_PERIOD;

            $display("    negedge vsync en t = %0d ns", t_vsync);
            $display("");
            $display("  >>> Zoom aqui en el waveform viewer:");
            $display("  >>> grn=F (verde) desde t = %0d ns", t_green);
            $display("  >>> grn=F (verde) hasta t = %0d ns", t_green_end);
            $display("  >>> Duracion visible      = 25,600 ns");
            $display("  >>> Escala recomendada    = 5 us/div");
            $display("");
        end

        // Navegar hasta justo antes de la linea verde 
        repeat (CYCLES_TO_GREEN - 5) @(posedge clk);

        // Verificar que grn=0 ANTES de la linea
        $display("[4] Verificacion: grn=0 justo antes de la fila verde");
        check_cond("grn=0 antes de la linea verde",  grn === 4'h0);
        check_cond("blu=0 en blanking horizontal previo", blu === 4'h0);

        // Avanzar hasta el primer pixel verde (+ pipeline delay de 1 ciclo)
        repeat (6) @(posedge clk); #1;  // 5 ciclos de margen + 1 de pipeline

        // Verificar que grn=F durante al menos 10 ciclos consecutivos
        $display("[5] Verificacion: grn=F durante la linea verde");
        begin
            int green_cycles = 0;
            for (int i = 0; i < H_VISIBLE; i++) begin
                if (grn === 4'hF && red === 4'h0 && blu === 4'h0)
                    green_cycles++;
                @(posedge clk); #1;
            end
            $display("    Ciclos con grn=F detectados: %0d de %0d esperados",
                     green_cycles, H_VISIBLE);
            // Se acepta +-2 ciclos por el pipeline y el margen de entrada
            check_cond("grn=F durante la linea verde (>= 630 ciclos)",
                       green_cycles >= 630);
        end

        // Verificar que grn vuelve a 0 despues de la linea 
        @(posedge clk); #1;
        $display("[6] Verificacion: grn=0 despues de la linea verde");
        check_cond("grn=0 despues de la linea verde", grn === 4'h0);

        // Dejar correr 2 lineas mas para que se vea el patron en waveform 
        repeat (2 * H_TOTAL) @(posedge clk);

        // Resumen
        $display("\n============================================");
        $display(" Resultados: %0d PASS  |  %0d FAIL",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display(" TODOS LOS TESTS PASARON");
        else
            $display(" ALGUNOS TESTS FALLARON");
        $display("============================================");
        $finish;
    end

    //  Timeout 
    initial begin
        #100_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule