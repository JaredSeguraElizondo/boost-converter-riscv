// ============================================================================
// Testbench: tb_bus_infrastructure
// Proyecto 3 — Control digital RISC-V / Convertidor Boost
// ============================================================================
// Descripción:
//   Banco de pruebas autoverificable para los módulos address_decoder y
//   read_mux. Verifica exhaustivamente:
//     1. Selección correcta (sel_o) para cada periférico y RAM
//     2. Write-enable individual activado solo para el periférico correcto
//     3. Que los demás WE permanezcan inactivos (exclusividad)
//     4. Lectura correcta del mux para cada fuente de datos
//     5. Comportamiento ante direcciones fuera de rango
//     6. Que we_i=0 desactiva todos los write-enables
//
// Ejecución:
//   iverilog -g2012 -o tb_bus tb_bus_infrastructure.sv \
//            ../rtl/address_decoder.sv ../rtl/read_mux.sv
//   vvp tb_bus
// ============================================================================

`timescale 1ns / 1ps

module tb_bus_infrastructure;

    // ========================================================================
    // Señales del testbench
    // ========================================================================
    logic [31:0] address;
    logic        we;

    // Salidas del decoder
    logic [2:0]  sel;
    logic        we_ram, we_uart, we_pwm, we_adc, we_vga, we_gpio;

    // Datos simulados de periféricos (patrones únicos para verificación)
    logic [31:0] data_ram  = 32'hAAAA_0000;
    logic [31:0] data_uart = 32'hBBBB_1111;
    logic [31:0] data_pwm  = 32'hCCCC_2222;
    logic [31:0] data_adc  = 32'hDDDD_3333;
    logic [31:0] data_vga  = 32'hEEEE_4444;
    logic [31:0] data_gpio = 32'hFFFF_5555;

    // Salida del mux
    logic [31:0] data_out;

    // Contadores de pruebas
    int pass_count = 0;
    int fail_count = 0;
    int test_num   = 0;

    // ========================================================================
    // Instancias de los módulos bajo prueba (DUT)
    // ========================================================================
    address_decoder u_decoder (
        .address_i  (address),
        .we_i       (we),
        .sel_o      (sel),
        .we_ram_o   (we_ram),
        .we_uart_o  (we_uart),
        .we_pwm_o   (we_pwm),
        .we_adc_o   (we_adc),
        .we_vga_o   (we_vga),
        .we_gpio_o  (we_gpio)
    );

    read_mux u_mux (
        .sel_i       (sel),
        .data_ram_i  (data_ram),
        .data_uart_i (data_uart),
        .data_pwm_i  (data_pwm),
        .data_adc_i  (data_adc),
        .data_vga_i  (data_vga),
        .data_gpio_i (data_gpio),
        .data_out_o  (data_out)
    );

    // ========================================================================
    // Tarea de verificación genérica
    // ========================================================================
    task automatic check(
        input string      test_name,
        input logic [2:0]  exp_sel,
        input logic        exp_we_ram,
        input logic        exp_we_uart,
        input logic        exp_we_pwm,
        input logic        exp_we_adc,
        input logic        exp_we_vga,
        input logic        exp_we_gpio,
        input logic [31:0] exp_data
    );
        test_num++;
        #1; // Espera propagación combinacional

        if (sel      !== exp_sel     ||
            we_ram   !== exp_we_ram  ||
            we_uart  !== exp_we_uart ||
            we_pwm   !== exp_we_pwm  ||
            we_adc   !== exp_we_adc  ||
            we_vga   !== exp_we_vga  ||
            we_gpio  !== exp_we_gpio ||
            data_out !== exp_data) begin

            $display("[FAIL] Test %0d: %s", test_num, test_name);
            $display("       addr=0x%08h  we=%b", address, we);
            $display("       sel:  got=%0d  exp=%0d", sel, exp_sel);
            $display("       we_ram:  got=%b  exp=%b", we_ram,  exp_we_ram);
            $display("       we_uart: got=%b  exp=%b", we_uart, exp_we_uart);
            $display("       we_pwm:  got=%b  exp=%b", we_pwm,  exp_we_pwm);
            $display("       we_adc:  got=%b  exp=%b", we_adc,  exp_we_adc);
            $display("       we_vga:  got=%b  exp=%b", we_vga,  exp_we_vga);
            $display("       we_gpio: got=%b  exp=%b", we_gpio, exp_we_gpio);
            $display("       data:  got=0x%08h  exp=0x%08h", data_out, exp_data);
            fail_count++;
        end else begin
            $display("[PASS] Test %0d: %s", test_num, test_name);
            pass_count++;
        end
    endtask

    // ========================================================================
    // Secuencia de pruebas
    // ========================================================================
    initial begin
        $display("============================================================");
        $display(" Testbench: Bus Infrastructure (Address Decoder + Read Mux)");
        $display("============================================================");
        $display("");

        // ────────────────────────────────────────────────────────────────────
        // Grupo 1: Lectura (we=0) — Verificar selección correcta
        // ────────────────────────────────────────────────────────────────────
        $display("--- Grupo 1: Lectura (we=0) - Selección de periféricos ---");

        we = 1'b0;

        // Test: RAM base
        address = 32'h0000_2000;
        check("RAM base (0x2000)", 3'd0, 0,0,0,0,0,0, data_ram);

        // Test: RAM mitad
        address = 32'h0000_2800;
        check("RAM mitad (0x2800)", 3'd0, 0,0,0,0,0,0, data_ram);

        // Test: RAM tope
        address = 32'h0000_2FFC;
        check("RAM tope (0x2FFC)", 3'd0, 0,0,0,0,0,0, data_ram);

        // Test: UART Control/Estado
        address = 32'h0001_0040;
        check("UART Ctrl (0x0040)", 3'd1, 0,0,0,0,0,0, data_uart);

        // Test: UART TX Data
        address = 32'h0001_0044;
        check("UART TX (0x0044)", 3'd1, 0,0,0,0,0,0, data_uart);

        // Test: UART RX Data
        address = 32'h0001_0048;
        check("UART RX (0x0048)", 3'd1, 0,0,0,0,0,0, data_uart);

        // Test: PWM Control/Estado
        address = 32'h0001_0100;
        check("PWM Ctrl (0x0100)", 3'd2, 0,0,0,0,0,0, data_pwm);

        // Test: PWM Duty
        address = 32'h0001_0104;
        check("PWM Duty (0x0104)", 3'd2, 0,0,0,0,0,0, data_pwm);

        // Test: ADC Control/Estado
        address = 32'h0001_0110;
        check("ADC Ctrl (0x0110)", 3'd3, 0,0,0,0,0,0, data_adc);

        // Test: ADC Dato
        address = 32'h0001_0114;
        check("ADC Dato (0x0114)", 3'd3, 0,0,0,0,0,0, data_adc);

        // Test: VGA Control
        address = 32'h0001_0120;
        check("VGA Ctrl (0x0120)", 3'd4, 0,0,0,0,0,0, data_vga);

        // Test: VGA Plot Data
        address = 32'h0001_0124;
        check("VGA Plot (0x0124)", 3'd4, 0,0,0,0,0,0, data_vga);

        // Test: GPIO Estado
        address = 32'h0001_0130;
        check("GPIO Est (0x0130)", 3'd5, 0,0,0,0,0,0, data_gpio);

        // ────────────────────────────────────────────────────────────────────
        // Grupo 2: Escritura (we=1) — Verificar WE individuales
        // ────────────────────────────────────────────────────────────────────
        $display("");
        $display("--- Grupo 2: Escritura (we=1) - Write-enables ---");

        we = 1'b1;

        address = 32'h0000_2000;
        check("WR RAM",  3'd0, 1,0,0,0,0,0, data_ram);

        address = 32'h0001_0040;
        check("WR UART", 3'd1, 0,1,0,0,0,0, data_uart);

        address = 32'h0001_0100;
        check("WR PWM",  3'd2, 0,0,1,0,0,0, data_pwm);

        address = 32'h0001_0110;
        check("WR ADC",  3'd3, 0,0,0,1,0,0, data_adc);

        address = 32'h0001_0120;
        check("WR VGA",  3'd4, 0,0,0,0,1,0, data_vga);

        address = 32'h0001_0130;
        check("WR GPIO", 3'd5, 0,0,0,0,0,1, data_gpio);

        // ────────────────────────────────────────────────────────────────────
        // Grupo 3: Direcciones fuera de rango
        // ────────────────────────────────────────────────────────────────────
        $display("");
        $display("--- Grupo 3: Direcciones fuera de rango ---");

        // Dirección en ROM (no debe seleccionar nada en data bus)
        we = 1'b0;
        address = 32'h0000_0000;
        check("ROM (0x0000) → ninguno", 3'd7, 0,0,0,0,0,0, 32'h0);

        address = 32'h0000_1000;
        check("ROM (0x1000) → ninguno", 3'd7, 0,0,0,0,0,0, 32'h0);

        // Dirección en espacio de periféricos pero sin periférico asignado
        address = 32'h0001_0200;
        check("Periph no asignado (0x0200)", 3'd7, 0,0,0,0,0,0, 32'h0);

        address = 32'h0001_0000;
        check("Periph base sin asignar (0x0000)", 3'd7, 0,0,0,0,0,0, 32'h0);

        // Dirección completamente fuera del mapa
        address = 32'hFFFF_FFFF;
        check("Máxima (0xFFFFFFFF)", 3'd7, 0,0,0,0,0,0, 32'h0);

        address = 32'h0002_0000;
        check("Región inexistente (0x20000)", 3'd7, 0,0,0,0,0,0, 32'h0);

        // Fuera de rango con escritura activa → WE no debe activarse
        we = 1'b1;
        address = 32'hDEAD_BEEF;
        check("WR fuera de rango → sin WE", 3'd7, 0,0,0,0,0,0, 32'h0);

        address = 32'h0001_FFFF;
        check("WR periph no asignado → sin WE", 3'd7, 0,0,0,0,0,0, 32'h0);

        // ────────────────────────────────────────────────────────────────────
        // Grupo 4: Exclusividad de write-enables
        // ────────────────────────────────────────────────────────────────────
        $display("");
        $display("--- Grupo 4: Exclusividad de WE (solo uno activo) ---");

        we = 1'b1;

        // Escribir a PWM → solo we_pwm debe estar activo
        address = 32'h0001_0104;
        check("WR PWM duty → solo we_pwm", 3'd2, 0,0,1,0,0,0, data_pwm);

        // Escribir a ADC → solo we_adc debe estar activo
        address = 32'h0001_0110;
        check("WR ADC ctrl → solo we_adc", 3'd3, 0,0,0,1,0,0, data_adc);

        // Escribir a UART TX → solo we_uart debe estar activo
        address = 32'h0001_0044;
        check("WR UART TX → solo we_uart", 3'd1, 0,1,0,0,0,0, data_uart);

        // ────────────────────────────────────────────────────────────────────
        // Grupo 5: Transiciones rápidas de dirección
        // ────────────────────────────────────────────────────────────────────
        $display("");
        $display("--- Grupo 5: Transiciones rápidas ---");

        we = 1'b0;

        address = 32'h0000_2000; #1;
        address = 32'h0001_0110; #1;
        address = 32'h0001_0040; #1;
        address = 32'hFFFF_0000;
        check("Transición rápida → fuera rango", 3'd7, 0,0,0,0,0,0, 32'h0);

        address = 32'h0001_0130;
        check("Transición rápida → GPIO", 3'd5, 0,0,0,0,0,0, data_gpio);

        // ════════════════════════════════════════════════════════════════════
        // Resumen final
        // ════════════════════════════════════════════════════════════════════
        $display("");
        $display("============================================================");
        $display(" RESULTADOS: %0d PASSED, %0d FAILED de %0d tests",
                 pass_count, fail_count, test_num);
        if (fail_count == 0)
            $display(" >>> TODOS LOS TESTS PASARON <<<");
        else
            $display(" >>> HAY FALLOS — REVISAR <<<");
        $display("============================================================");

        $finish;
    end

endmodule
