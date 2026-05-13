
`timescale 1ns/1ps

module memoria_datos_tb;

    localparam integer Ancho_Dato      = 32;
    localparam integer Ancho_Direccion = 32;
    localparam integer Tamanio_Mem     = 256;

    logic clk;
    logic escritura_habilitada;
    logic lectura_habilitada;
    logic [Ancho_Direccion-1:0] direccion;
    logic [Ancho_Dato-1:0]      dato_escritura;
    wire  [Ancho_Dato-1:0]      dato_lectura;

    memoria_datos #(
        .Ancho_Dato      (Ancho_Dato),
        .Ancho_Direccion (Ancho_Direccion),
        .Tamanio_Mem     (Tamanio_Mem)
    ) dut (
        .clk                   (clk),
        .escritura_habilitada  (escritura_habilitada),
        .lectura_habilitada    (lectura_habilitada),
        .direccion             (direccion),
        .dato_escritura        (dato_escritura),
        .dato_lectura          (dato_lectura)
    );

    initial begin
        $dumpfile("memoria_datos_tb.vcd");
        $dumpvars(0, memoria_datos_tb);
    end

    initial begin
        clk = 0;
        forever #5 clk = ~clk;   10 ns
    end

    initial begin

        escritura_habilitada = 0;
        lectura_habilitada   = 0;
        direccion            = '0;
        dato_escritura       = '0;

        #20;

        $display("---------------------------------------------------------------");
        $display("  Tiempo | Escribir | Direccion | Dato_Escritura | Dato_Lectura");
        $display("---------------------------------------------------------------");

        @(posedge clk);
        escritura_habilitada = 1;
        direccion            = 32'h0000_0000;  
        #10; 
        dato_escritura       = 32'hDEAD_BEEF;
        #10; 
        @(posedge clk);
        escritura_habilitada = 0;  

        @(posedge clk);
        escritura_habilitada = 1;
        direccion            = 32'h0000_0004;  
        #10; 
        dato_escritura       = 32'hCAFE_BABE;
        #10;
        @(posedge clk);
        escritura_habilitada = 0;

        @(posedge clk);
        escritura_habilitada = 1;
        direccion            = 32'h0000_0010;  
        #10; 
        dato_escritura       = 32'h1234_5678;
        #10;
        @(posedge clk);
        escritura_habilitada = 0;

        @(posedge clk);
        escritura_habilitada = 1;
        direccion            = 32'h0000_03FC;  // índice = 255
        #10; 
        dato_escritura       = 32'hABCD_EF01;
        #10;
        @(posedge clk);
        escritura_habilitada = 0;

        #10;

        lectura_habilitada = 1;

        direccion = 32'h0000_0000;
        #2; 
        $display("%8t |   Read   |  0x%08h |       0x%08h |    0x%08h",
                 $time, direccion, 32'hDEAD_BEEF, dato_lectura);

        direccion = 32'h0000_0004;
        #2;
        $display("%8t |   Read   |  0x%08h |       0x%08h |    0x%08h",
                 $time, direccion, 32'hCAFE_BABE, dato_lectura);

        direccion = 32'h0000_0010;
        #2;
        $display("%8t |   Read   |  0x%08h |       0x%08h |    0x%08h",
                 $time, direccion, 32'h1234_5678, dato_lectura);

        direccion = 32'h0000_03FC;
        #2;
        $display("%8t |   Read   |  0x%08h |       0x%08h |    0x%08h",
                 $time, direccion, 32'hABCD_EF01, dato_lectura);

        lectura_habilitada = 0;
        direccion          = 32'h0000_0000; 
        #2;
        $display("%8t |   ReadDis | 0x%08h |   xxxxxxxx    |    0x%08h",
                 $time, direccion, dato_lectura);


        $display("---------------------------------------------------------------");
        #10;
        $finish;
    end

endmodule
