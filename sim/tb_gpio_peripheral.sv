`timescale 1ns / 1ps
`timescale 1ns / 1ps

module tb_gpio_peripheral;

    logic        clk_i;
    logic        rst_i;
    logic [31:0] rdata_o;
    logic        boton_i;

    localparam int DEBOUNCE_TIME_NS = 10_000_000; // 10 ms

    gpio_peripheral dut (
        .clk_i   (clk_i),
        .rst_i   (rst_i),
        .rdata_o (rdata_o),
        .boton_i (boton_i)
    );

    initial clk_i = 0;
    always #5 clk_i = ~clk_i;


    task automatic presionar_boton(input int duracion_ms);
        begin
            $display("[%0t ns] === Presionando boton (limpio, %0d ms) ===",
                     $time, duracion_ms);
            boton_i = 1'b1;
            #(duracion_ms * 1_000_000);
            boton_i = 1'b0;
            $display("[%0t ns] === Soltando boton ===", $time);
        end
    endtask

    task automatic presionar_con_rebotes(input int duracion_ms);
        begin
            $display("[%0t ns] === Presionando boton CON REBOTES ===", $time);

            boton_i = 1'b1; #150_000;
            boton_i = 1'b0; #80_000;
            boton_i = 1'b1; #200_000;
            boton_i = 1'b0; #100_000;
            boton_i = 1'b1; #50_000;
            boton_i = 1'b0; #30_000;
            boton_i = 1'b1; // ya estable

            #((duracion_ms - 2) * 1_000_000);

            boton_i = 1'b0; #100_000;
            boton_i = 1'b1; #50_000;
            boton_i = 1'b0; #80_000;
            boton_i = 1'b1; #30_000;
            boton_i = 1'b0; 

            $display("[%0t ns] === Soltando boton (con rebotes) ===", $time);
        end
    endtask

    task automatic glitch_corto;
        begin
            $display("[%0t ns] === Glitch corto (deberia IGNORARSE) ===",
                     $time);
            boton_i = 1'b1;
            #500_000;          
            boton_i = 1'b0;
        end
    endtask

    logic prev_estado;
    initial prev_estado = 0;

    always @(posedge clk_i) begin
        if (rdata_o[0] !== prev_estado) begin
            $display("[%0t ns] >>> rdata_o[0] cambio: %b (registro = 0x%08h)",
                     $time, rdata_o[0], rdata_o);
            prev_estado <= rdata_o[0];
        end
    end

    initial begin

        rst_i   = 1'b1;
        boton_i = 1'b0;

        #200;
        @(posedge clk_i);
        rst_i <= 1'b0;
        #1000;

        $display("============================================");
        $display(" Test 1: pulsacion limpia de 50 ms");
        $display("============================================");
        $display("Esperado: rdata_o[0] sube a 1 luego de ~10 ms,");
        $display("          baja a 0 luego de ~10 ms al soltar");
        presionar_boton(50);

        // Esperar a que el debounce confirme la liberacion
        #15_000_000;

        $display("");
        $display("============================================");
        $display(" Test 2: pulsacion con rebotes");
        $display("============================================");
        $display("Esperado: rdata_o[0] solo cambia una vez al subir");
        $display("          y una vez al bajar (los rebotes se filtran)");
        presionar_con_rebotes(40);
        #15_000_000;

        $display("");
        $display("============================================");
        $display(" Test 3: glitch corto (0.5 ms)");
        $display("============================================");
        $display("Esperado: rdata_o[0] NO cambia (filtrado por debounce)");
        glitch_corto();
        #15_000_000;

        $display("");
        $display("============================================");
        $display(" Test 4: dos pulsaciones rapidas");
        $display("============================================");
        presionar_boton(30);
        #15_000_000;
        presionar_boton(30);
        #15_000_000;

        $display("");
        $display("============================================");
        $display(" Simulacion finalizada");
        $display("============================================");
        $finish;
    end

    initial begin
        $timeformat(-6, 1, " us", 12);
    end

endmodule
