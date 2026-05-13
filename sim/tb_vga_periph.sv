
//   Testbench autoverificable para el periférico VGA completo (vga_periph).
//   Compatible con Post-Implementation Functional Simulation en Vivado.


`timescale 1ns / 1ps

module tb_vga_periph;

    //  Parámetros del banco 
    localparam int CLK_PERIOD   = 40;    // ns (25 MHz)
    localparam int H_TOTAL      = 800;
    localparam int H_VISIBLE    = 640;
    localparam int H_SYNC_W     = 96;
    localparam int V_TOTAL      = 525;
    localparam int V_VISIBLE    = 480;
    localparam int V_SYNC_W     = 2;

    //  Señales del DUT 
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

    //  Instancia del DUT 
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

    //  Generación de reloj 
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    //  Contadores de resultado 
    int pass_count;
    int fail_count;

    //  Tarea: verificación con mensaje 
    task automatic check_cond (
        input string  test_name,
        input logic   condition
    );
        if (condition) begin
            $display("  PASS [%s]", test_name);
            pass_count++;
        end else begin
            $display("  FAIL [%s]", test_name);
            fail_count++;
        end
    endtask

    //  Tarea: escritura al bus
    task automatic bus_write (
        input logic [3:0]  off,
        input logic [31:0] data
    );
        @(posedge clk); #1;
        offset <= off;
        wdata  <= data;
        we     <= 1'b1;
        @(posedge clk); #1;
        we     <= 1'b0;
    endtask

    //  Tarea: medir período de una señal (flanco bajada a bajada)
    task automatic measure_period_ns (
        input  string  sig_name,
        ref    logic   sig,
        output longint period_ns
    );
        longint t0, t1;
        @(negedge sig); t0 = $time;
        @(negedge sig); t1 = $time;
        period_ns = t1 - t0;
        $display("  INFO [%s] periodo medido = %0d ns", sig_name, period_ns);
    endtask

    //  Tarea: medir ancho de pulso bajo
    task automatic measure_pulse_width_ns (
        input  string  sig_name,
        ref    logic   sig,
        output longint width_ns
    );
        longint t_fall, t_rise;
        @(negedge sig); t_fall = $time;
        @(posedge sig); t_rise = $time;
        width_ns = t_rise - t_fall;
        $display("  INFO [%s] ancho de pulso = %0d ns", sig_name, width_ns);
    endtask

    // Secuencia principal de pruebas 
    initial begin
        // Inicialización
        pass_count = 0;
        fail_count = 0;
        rst    = 1'b1;
        we     = 1'b0;
        offset = 4'h0;
        wdata  = 32'h0;

        $display("========================================");
        $display(" Inicio de simulación");
        $display("========================================");

        repeat (5) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        //  T1: Estado de reset
        $display("\n[T1] Estado de reset");
        check_cond("HSYNC=1 en reset",  hsync === 1'b1);
        check_cond("VSYNC=1 en reset",  vsync === 1'b1);
        check_cond("RED=0  en reset",   red   === 4'h0);
        check_cond("GRN=0  en reset",   grn   === 4'h0);
        check_cond("BLU=0  en reset",   blu   === 4'h0);

        //  T2: Registro de control 
        $display("\n[T2] Registro de control");
        bus_write(4'h0, 32'h1);   // enable = 1
        @(posedge clk); #1;
        offset <= 4'h0; we <= 1'b0;
        @(posedge clk);
        check_cond("rdata[0]=1 tras habilitar", rdata[0] === 1'b1);

        bus_write(4'h0, 32'h0);   // enable = 0
        @(posedge clk); #1;
        offset <= 4'h0;
        @(posedge clk);
        check_cond("rdata[0]=0 tras deshabilitar", rdata[0] === 1'b0);

        // Re-habilitar para las pruebas siguientes
        bus_write(4'h0, 32'h1);

        //  T3: Período de HSYNC
        $display("\n[T3] Periodo de HSYNC");
        begin
            longint measured;
            longint expected;
            expected = H_TOTAL * CLK_PERIOD;  
            measure_period_ns("HSYNC", hsync, measured);
            check_cond("HSYNC periodo correcto",
                       measured === expected);
        end

        //  T4: Ancho del pulso HSYNC 
        $display("\n[T4] Ancho de pulso HSYNC");
        begin
            longint measured;
            longint expected;
            expected = H_SYNC_W * CLK_PERIOD;  // 96 * 40 = 3840 ns
            measure_pulse_width_ns("HSYNC", hsync, measured);
            check_cond("HSYNC ancho de pulso correcto",
                       measured === expected);
        end

        //  T5: Período de VSYNC
        $display("\n[T5] Periodo de VSYNC (esperar ~2 frames...)");
        begin
            longint measured;
            longint expected;
            expected = V_TOTAL * H_TOTAL * CLK_PERIOD;  // 525 * 800 * 40 = 16,800,000 ns
            measure_period_ns("VSYNC", vsync, measured);
            check_cond("VSYNC periodo correcto",
                       measured === expected);
        end

        // T6: RGB = 0 durante blanking horizontal 
        // Después del flanco de bajada de HSYNC estamos en la zona de sync,
        // que es parte del blanking. video_on = 0 a render da salida cero.
        // El render registra en la siguiente arista, así que esperamos 2 ciclos.
        $display("\n[T6] RGB = 0 durante blanking horizontal");
        @(negedge hsync);
        repeat (2) @(posedge clk); #1;
        check_cond("RED=0 durante H-blanking", red === 4'h0);
        check_cond("GRN=0 durante H-blanking", grn === 4'h0);
        check_cond("BLU=0 durante H-blanking", blu === 4'h0);

        // T7: Píxel verde tras escritura de muestra 
        // Se escribe adc_sample = 0 → Y_pixel = 479 (fila de fondo).
        // El buffer guarda el dato en wr_ptr=0 (tras reset).
        // Se espera el inicio del siguiente frame y se monitorea la fila 479.
        // Si aparece un píxel verde, el pipeline timing→buffer→render funciona.
        $display("\n[T7] Deteccion de pixel verde tras escritura de muestra");
        begin
            logic green_found;
            int   pixel_count;
            green_found = 1'b0;
            pixel_count = 0;

            // Escribir muestra: adc = 0 → Y = 479
            bus_write(4'h4, 32'h000);

            // Esperar inicio de frame (flanco de bajada de VSYNC)
            @(negedge vsync);

            // Monitorear V_TOTAL x H_TOTAL ciclos buscando verde.
            // El negedge vsync ocurre en vcount=490. El area visible del
            // siguiente frame no empieza hasta vcount=0, que tarda otros
            // (525-490) x 800 = 28,000 ciclos. Si solo se monitorearan
            // V_VISIBLE x H_TOTAL = 384,000 ciclos el pixel verde quedaria
            // fuera de la ventana (aparece en el ciclo ~411,000).
            // Con V_TOTAL x H_TOTAL = 420,000 ciclos se cubre el frame completo.
            repeat (V_TOTAL * H_TOTAL) begin
                @(posedge clk); #1;
                if (grn === 4'hF && red === 4'h0 && blu === 4'h0) begin
                    green_found = 1'b1;
                end
                pixel_count++;
            end

            check_cond("Pixel verde detectado en frame tras escritura",
                       green_found === 1'b1);
        end

        // T8: Deshabilitar apaga las salidas 
        $display("\n[T8] Deshabilitar VGA apaga salidas");
        bus_write(4'h0, 32'h0);   // enable = 0
        repeat (2) @(posedge clk); #1;
        check_cond("HSYNC=1 tras deshabilitar", hsync === 1'b1);
        check_cond("VSYNC=1 tras deshabilitar", vsync === 1'b1);
        check_cond("RED=0  tras deshabilitar",  red   === 4'h0);
        check_cond("GRN=0  tras deshabilitar",  grn   === 4'h0);
        check_cond("BLU=0  tras deshabilitar",  blu   === 4'h0);

        // Resumen
        #100;
        $display("\n========================================");
        $display(" Resultados: %0d PASS  |  %0d FAIL",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display(" TODOS LOS TESTS PASARON");
        else
            $display(" ALGUNOS TESTS FALLARON — revisar log");
        $display("========================================");
        $finish;
    end

    // Timeout global 
    initial begin
        #2_000_000_000;
        $display("TIMEOUT: la simulacion supero el límite de 2 s simulados.");
        $finish;
    end

endmodule