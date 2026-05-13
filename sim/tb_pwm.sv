`timescale 1ns/1ps

module pwm_tb;

    // -------------------------------------------------------------------------
    // Senales del DUT
    // -------------------------------------------------------------------------
    logic        clk;
    logic        rst;
    logic        sel;
    logic        we;
    logic [3:0]  addr;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic        pwm_out;
    logic        pwm_trig;


    // Instancia del DUT
    pwm dut (
        .clk_i        (clk),
        .rst_i        (rst),
        .sel_i        (sel),
        .we_i         (we),
        .addr_i       (addr),
        .wdata_i      (wdata),
        .rdata_o      (rdata),
        .pwm_o        (pwm_out),
        .pwm_trigger_o(pwm_trig)
    );


    // Reloj de 100 MHz: periodo de 10 ns

    initial clk = 1'b0;
    always #5 clk = ~clk;

    
    // Constantes para legibilidad
    
    localparam logic [3:0] ADDR_CTRL = 4'h0;
    localparam logic [3:0] ADDR_DUTY = 4'h4;

    localparam logic [1:0] FREQ_25K  = 2'b00;
    localparam logic [1:0] FREQ_50K  = 2'b01;
    localparam logic [1:0] FREQ_100K = 2'b10;

    // Periodo del lazo de control PI: 200 us (5 kHz)
    localparam time PI_PERIOD = 200_000;  // ns

    
    // Tarea: escribir un registro via el bus
    task automatic bus_write(input logic [3:0] address, input logic [31:0] data);
        @(posedge clk);
        sel   <= 1'b1;
        we    <= 1'b1;
        addr  <= address;
        wdata <= data;
        @(posedge clk);
        sel   <= 1'b0;
        we    <= 1'b0;
        addr  <= 4'h0;
        wdata <= 32'h0;
    endtask

    
    // Tarea: leer un registro via el bus
    
    task automatic bus_read(input logic [3:0] address, output logic [31:0] data);
        @(posedge clk);
        sel  <= 1'b1;
        we   <= 1'b0;
        addr <= address;
        @(negedge clk);
        data = rdata;
        @(posedge clk);
        sel  <= 1'b0;
        addr <= 4'h0;
    endtask


    // Helper: configura enable=1 con la frecuencia y duty dados
   
    task automatic config_pwm(
        input logic [1:0] freq_sel,
        input logic [6:0] duty_pct
    );
        bus_write(ADDR_DUTY, {25'd0, duty_pct});
        bus_write(ADDR_CTRL, {29'd0, freq_sel, 1'b1});  // enable = 1
    endtask

    
    // Tarea: mide el periodo entre dos pulsos de pwm_trigger_o

    task automatic measure_period(
        input string label,
        input real   expected_khz
    );
        time t_start, t_end;
        real period_us;
        real freq_khz;

        @(posedge pwm_trig);
        t_start = $time;
        @(posedge pwm_trig);
        t_end = $time;

        period_us = real'(t_end - t_start) / 1000.0;
        freq_khz  = 1000.0 / period_us;

        $display("  [%s] periodo = %7.3f us | freq = %7.3f kHz (esperado %0.1f kHz)",
                 label, period_us, freq_khz, expected_khz);
    endtask

    
    // Secuencia principal de prueba
    
    initial begin
        // Inicializacion
        rst   = 1'b1;
        sel   = 1'b0;
        we    = 1'b0;
        addr  = 4'h0;
        wdata = 32'h0;

        repeat (5) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        $display("================================================");
        $display(" Inicia prueba del modulo PWM");
        $display("================================================");

        
        // Test 1: barrido de frecuencias con duty fijo en 50%
        // Verifica que las 3 frecuencias dan exactas
        
        $display("\n-- Test 1: barrido de frecuencias (duty=50%%) --");

        config_pwm(FREQ_25K, 7'd50);
        repeat (3) measure_period("25 kHz / 50%", 25.0);

        config_pwm(FREQ_50K, 7'd50);
        repeat (3) measure_period("50 kHz / 50%", 50.0);

        config_pwm(FREQ_100K, 7'd50);
        repeat (3) measure_period("100 kHz / 50%", 100.0);

        
        // Test 2: rampa de duty simulando el lazo de control PI
        // El RISC-V escribira el registro de duty cada 200 us (5 kHz). Aca
        // el testbench imita ese comportamiento haciendo una rampa subir-bajar.
        // En el waveform se debe ver pwm_out con pulsos que crecen suavemente
        // y luego se achican, sin glitches en las transiciones (gracias al
        // doble buffer interno del modulo).
        
        $display("\n-- Test 2: rampa de duty a 50 kHz (cada %0t ns = 5 kHz) --",
                 PI_PERIOD);

        // Asegurar que estamos a 50 kHz para esta prueba
        bus_write(ADDR_CTRL, {29'd0, FREQ_50K, 1'b1});

        $display("  rampa subiendo: 0%% -> 80%% (paso de 5%%)");
        for (int duty = 0; duty <= 80; duty += 5) begin
            bus_write(ADDR_DUTY, 32'(duty));
            #PI_PERIOD;
        end

        $display("  rampa bajando: 80%% -> 0%% (paso de 5%%)");
        for (int duty = 80; duty >= 0; duty -= 5) begin
            bus_write(ADDR_DUTY, 32'(duty));
            #PI_PERIOD;
        end

        // Verifica que despues de toda la rampa la frecuencia sigue siendo
        // exacta (el doble buffer no se descuajeringo con tantas escrituras)
        $display("  verificando frecuencia despues de la rampa:");
        config_pwm(FREQ_50K, 7'd50);
        repeat (2) measure_period("50 kHz / 50% post-rampa", 50.0);

        
        // Test 3: saturacion (escribir 150 debe quedar en 100)
        
        $display("\n-- Test 3: saturacion de duty (escribir 150) --");
        config_pwm(FREQ_50K, 7'd25);
        @(posedge pwm_trig);
        bus_write(ADDR_DUTY, 32'd150);
        begin
            logic [31:0] readback;
            bus_read(ADDR_DUTY, readback);
            if (readback[6:0] == 7'd100)
                $display("  OK: lectura del registro duty = %0d (saturado a 100)",
                         readback[6:0]);
            else
                $display("  ERROR: duty leido = %0d, esperado 100", readback[6:0]);
        end

        
        // Test 4: deshabilitar el modulo (salidas deben quedar en 0)
        
        $display("\n-- Test 4: deshabilitar PWM --");
        bus_write(ADDR_CTRL, 32'h0);
        repeat (2500) @(posedge clk);
        if (pwm_out == 1'b0 && pwm_trig == 1'b0)
            $display("  OK: pwm_out=0 y pwm_trig=0 con enable=0");
        else
            $display("  ERROR: pwm_out=%b, pwm_trig=%b (deberian ser 0)",
                     pwm_out, pwm_trig);

        $display("\n================================================");
        $display(" Prueba terminada");
        $display("================================================");
        $finish;
    end

    
    // Watchdog: aborta si la simulacion se cuelga.
    // El test 2 (rampa) toma ~7 ms, asi que ponemos 15 ms de margen.
    
    initial begin
        #15_000_000;
        $display("ERROR: timeout de simulacion");
        $finish;
    end

endmodule