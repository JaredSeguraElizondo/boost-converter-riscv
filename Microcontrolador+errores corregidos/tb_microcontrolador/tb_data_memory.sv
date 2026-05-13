`timescale 1ns/1ps

module tb_data_memory();
    logic clk;
    logic reset;
    logic WE;
    logic [31:0] A;
    logic [31:0] WD;
    logic [31:0] RD;

    data_memory #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .MEM_SIZE(256)
    ) uut (
        .clk(clk),
        .reset(reset),
        .WE(WE),
        .A(A),
        .WD(WD),
        .RD(RD)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("tb_data_memory.vcd");
        $dumpvars(0, tb_data_memory);

        reset = 1;
        WE = 0;
        A = 32'h0000_0000;
        WD = 32'h0000_0000;
        #10;

        reset = 0;
        WE = 1;
        A = 32'h0000_0010;  
        WD = 32'hCAFE_BABE;
        #10;
        WE = 0;
        #5;
        if (RD !== 32'hCAFE_BABE) $error("Error Caso 1: Lectura incorrecta en 0x10");

        WE = 1;
        A = 32'h0000_0013;  
        WD = 32'hDEAD_BEEF;
        #10;
        WE = 0;
        A = 32'h0000_0010;
        #5;
        if (RD !== 32'hDEAD_BEEF) $error("Error Caso 2: Escritura no alineada falló");

        reset = 1;
        #10;
        reset = 0;
        A = 32'h0000_0010;
        #5;
        if (RD !== 32'h0000_0000) $error("Error Caso 3: Reset no limpió la memoria");
        
        $display("¡Todos los tests pasaron!");
        $finish;
    end
endmodule