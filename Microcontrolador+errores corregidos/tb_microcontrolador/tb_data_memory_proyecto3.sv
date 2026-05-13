
`timescale 1ns / 1ps

module tb_data_memory_proyecto3;

    // ── Parámetros ──
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 32;
    localparam MEM_SIZE   = 1024;         // 4 KB

    // ── Señales ──
    logic                  clk;
    logic                  reset;
    logic                  WE;
    logic [ADDR_WIDTH-1:0] A;
    logic [DATA_WIDTH-1:0] WD;
    logic [DATA_WIDTH-1:0] RD;

    // ── DUT ──
    data_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_SIZE  (MEM_SIZE)
    ) dut (
        .clk  (clk),
        .reset(reset),
        .WE   (WE),
        .A    (A),
        .WD   (WD),
        .RD   (RD)
    );

    // ── Reloj 100 MHz (10 ns) ──
    initial clk = 0;
    always  #5 clk = ~clk;

    // ── Contadores de tests ──
    int pass_cnt = 0;
    int fail_cnt = 0;

    // ── Task de verificación ──
    task check(
        input string    tag,
        input logic [31:0] addr,
        input logic [31:0] got,
        input logic [31:0] expected
    );
        if (got === expected) begin
            $display("PASS  %-30s  A=0x%08h  RD=0x%08h", tag, addr, got);
            pass_cnt++;
        end else begin
            $display("FAIL  %-30s  A=0x%08h  RD=0x%08h  (esperado 0x%08h)",
                     tag, addr, got, expected);
            $error("Mismatch en '%s'", tag);
            fail_cnt++;
        end
    endtask

    // ── Task de escritura ──
    // Aplica la dirección y dato antes del flanco, muestrea RD DESPUÉS.
    task write_word(
        input logic [31:0] addr,
        input logic [31:0] data
    );
        A  = addr;
        WD = data;
        WE = 1;
        @(posedge clk); #1;
        WE = 0;
    endtask

    // ── Task de lectura (asíncrona — solo cambia A) ──
    task read_word(input logic [31:0] addr);
        A = addr;
        #2; // propagación combinacional
    endtask

    // ── Secuencia principal ──
    initial begin
        $display("========================================================");
        $display("  Testbench data_memory — Proyecto 3 (1024 words, 4 KB)");
        $display("  Rango del bus: 0x0000_2000 – 0x0000_2FFF");
        $display("  Indexación:    A[11:2] → 10 bits");
        $display("========================================================");

        // ── Inicialización ──
        WE    = 0;
        reset = 1;
        A     = 32'h0000_2000;
        WD    = 32'h0;

        // ── CASO 1: Reset limpia la memoria ──
        @(posedge clk); #1;
        reset = 0;
        @(posedge clk); #1;  // un ciclo extra para que el reset propague

        read_word(32'h0000_2000);
        check("Reset limpia [0x2000]", A, RD, 32'h0);
        read_word(32'h0000_2FFC);
        check("Reset limpia [0x2FFC]", A, RD, 32'h0);

        $display("--- Caso 1 completo: reset ---");

        // ── CASO 2: Escritura y lectura básica ──
        // Simula: sw x7, 0(x14)  donde x14 = 0x2000 (ram_base)
        write_word(32'h0000_2000, 32'hDEAD_BEEF);
        read_word (32'h0000_2000);
        check("Escribe/lee 0x2000", A, RD, 32'hDEAD_BEEF);

        // Segunda muestra: address += 4
        write_word(32'h0000_2004, 32'hCAFE_BABE);
        read_word (32'h0000_2004);
        check("Escribe/lee 0x2004", A, RD, 32'hCAFE_BABE);

        // Tercera muestra (simula valor ADC típico = 2048 = 0x800)
        write_word(32'h0000_2008, 32'h0000_0800);
        read_word (32'h0000_2008);
        check("Muestra ADC 0x2008", A, RD, 32'h0000_0800);

        $display("--- Caso 2 completo: escritura/lectura básica ---");

        // ── CASO 3: Límite superior del rango (último word válido) ──
        // A = 0x2FFC → A[11:2] = 0x3FF = 1023 (índice 1023)
        write_word(32'h0000_2FFC, 32'hABCD_EF01);
        read_word (32'h0000_2FFC);
        check("Límite superior 0x2FFC", A, RD, 32'hABCD_EF01);

        $display("--- Caso 3 completo: límite superior ---");

        // ── CASO 4: WE=0 no escribe (read-only access) ──
        // Intenta sobrescribir 0x2000 con WE=0
        A  = 32'h0000_2000;
        WD = 32'hDEAD_0000;   // valor diferente
        WE = 0;
        @(posedge clk); #1;
        read_word(32'h0000_2000);
        check("WE=0 no modifica 0x2000", A, RD, 32'hDEAD_BEEF); // debe seguir con el valor original

        $display("--- Caso 4 completo: WE=0 protege ---");

        // ── CASO 5: Dirección no alineada (A[1:0] != 0) ──
        // A = 0x2001, 0x2002, 0x2003 → A[11:2] = 0 → mismo índice que 0x2000
        read_word(32'h0000_2001);
        check("No alineada 0x2001 → idx=0x2000", A, RD, 32'hDEAD_BEEF);
        read_word(32'h0000_2003);
        check("No alineada 0x2003 → idx=0x2000", A, RD, 32'hDEAD_BEEF);

        $display("--- Caso 5 completo: alineación ---");

        // ── CASO 6: Lectura anterior persiste (asincrónica) ──
        // Sin nuevo write, leer 0x2004 sigue retornando CAFE_BABE
        read_word(32'h0000_2004);
        check("Persistencia 0x2004", A, RD, 32'hCAFE_BABE);

        $display("--- Caso 6 completo: persistencia ---");

        // ── CASO 7: Reset después de escrituras limpia todo ──
        reset = 1;
        @(posedge clk); #1;
        reset = 0;

        read_word(32'h0000_2000);
        check("Post-reset 0x2000 = 0", A, RD, 32'h0);
        read_word(32'h0000_2004);
        check("Post-reset 0x2004 = 0", A, RD, 32'h0);
        read_word(32'h0000_2FFC);
        check("Post-reset 0x2FFC = 0", A, RD, 32'h0);

        $display("--- Caso 7 completo: reset post-escritura ---");

        // ── CASO 8: Escritura simultánea a varias muestras (simula el lazo PI) ──
        // El assembly guarda 512 muestras en 0x2000..0x27FC
        begin
            int i;
            for (i = 0; i < 8; i++) begin
                write_word(32'h0000_2000 + i*4, 32'h0000_0800 + i); // valor ADC + índice
            end
            for (i = 0; i < 8; i++) begin
                read_word(32'h0000_2000 + i*4);
                check($sformatf("Muestra[%0d]", i), A, RD, 32'h0000_0800 + i);
            end
        end

        $display("--- Caso 8 completo: ráfaga de muestras ---");

        // ── Resumen ──
        $display("========================================================");
        $display("  Resultado: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("  *** TODOS LOS TESTS PASARON ***");
        else
            $display("  *** %0d TEST(S) FALLARON ***", fail_cnt);
        $display("========================================================");

        $finish;
    end

endmodule
