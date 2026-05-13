`timescale 1ns / 1ps
 
module tb_uart_peripheral;
 
    logic        clk_cpu;
    logic        clk_uart;
    logic        rst_cpu;
    logic        rst_uart;
 
    logic        write_enable;
    logic [1:0]  addr;
    logic [31:0] wdata;
    logic [31:0] rdata;
 
    logic        RsRx;
    logic        RsTx;
 
    uart_peripheral dut (
        .clk_cpu_i      (clk_cpu),
        .rst_cpu_i      (rst_cpu),
        .write_enable_i (write_enable),
        .addr_i         (addr),
        .wdata_i        (wdata),
        .rdata_o        (rdata),
        .clk_uart_i     (clk_uart),
        .rst_uart_i     (rst_uart),
        .RsRx           (RsRx),
        .RsTx           (RsTx)
    );
 
    initial clk_cpu = 0;
    always #5 clk_cpu = ~clk_cpu;
 
    initial clk_uart = 0;
    always #31.25 clk_uart = ~clk_uart;
 
    task automatic enviar_byte(input [7:0] dato);
        begin
            $display("[TB %0t ns] CPU enviando byte 0x%02h (%c)",
                     $time, dato,
                     (dato >= 8'h20 && dato <= 8'h7E) ? dato : 8'h2E);
 
            @(posedge clk_cpu);
            write_enable <= 1'b1;
            addr         <= 2'b01;
            wdata        <= {24'h0, dato};
            @(posedge clk_cpu);
            write_enable <= 1'b0;
            wdata        <= 32'h0;
 
            repeat (5) @(posedge clk_cpu);
 
            @(posedge clk_cpu);
            write_enable <= 1'b1;
            addr         <= 2'b00;
            wdata        <= 32'h0000_0001;
            @(posedge clk_cpu);
            write_enable <= 1'b0;
            wdata        <= 32'h0;
 
            #150_000;
        end
    endtask
 
    task automatic leer_registro(input [1:0] direccion);
        begin
            @(posedge clk_cpu);
            write_enable <= 1'b0;
            addr         <= direccion;
            @(posedge clk_cpu);
            #1;
            $display("[TB %0t ns] Lectura addr=%b -> rdata = 0x%08h",
                     $time, direccion, rdata);
        end
    endtask
 
    initial begin
        rst_cpu      = 1'b1;
        rst_uart     = 1'b1;
        write_enable = 1'b0;
        addr         = 2'b00;
        wdata        = 32'h0;
        RsRx         = 1'b1;
 
        #500;
        @(posedge clk_cpu);
        rst_cpu  <= 1'b0;
        @(posedge clk_uart);
        rst_uart <= 1'b0;
 
        #1000;
 
        $display("============================================");
        $display(" Test 1: enviar Hi");
        $display("============================================");
        enviar_byte(8'h48);
        enviar_byte(8'h69);
        enviar_byte(8'h0A);
 
        #50_000;
 
        $display("============================================");
        $display(" Test 2: enviar 512 + CR + LF");
        $display("============================================");
        enviar_byte(8'h35);
        enviar_byte(8'h31);
        enviar_byte(8'h32);
        enviar_byte(8'h0D);
        enviar_byte(8'h0A);
 
        #50_000;
 
        $display("============================================");
        $display(" Test 3: leer registros");
        $display("============================================");
        leer_registro(2'b00);
        leer_registro(2'b01);
        leer_registro(2'b10);
 
        #20_000;
 
        $display("============================================");
        $display(" Simulacion finalizada");
        $display("============================================");
        $finish;
    end
 
    localparam real BIT_PERIOD_NS = 1.0e9 / 115200.0;
    logic [7:0] byte_rx;
    integer     i;
 
    initial begin
        byte_rx = 8'h00;
        @(negedge rst_cpu);
        #1000;
 
        forever begin
            @(negedge RsTx);
 
            #(BIT_PERIOD_NS * 1.5);
 
            for (i = 0; i < 8; i++) begin
                byte_rx[i] = RsTx;
                #(BIT_PERIOD_NS);
            end
 
            $display("[MONITOR %0t ns] RsTx recibio byte 0x%02h (%c)",
                     $time, byte_rx,
                     (byte_rx >= 8'h20 && byte_rx <= 8'h7E) ? byte_rx : 8'h2E);
        end
    end
 
    initial begin
        $timeformat(-9, 1, " ns", 10);
    end
 
endmodule
