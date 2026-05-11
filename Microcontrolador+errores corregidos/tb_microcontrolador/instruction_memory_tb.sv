`timescale 1ns/1ps

module instruction_memory_rv32i_tb;

    localparam DATA_WIDTH    = 32;
    localparam ADDRESS_WIDTH = 32;
    localparam MEM_SIZE      = 256;

    logic [ADDRESS_WIDTH-1:0] tb_address;
    wire  [DATA_WIDTH-1:0]    tb_instruction;

    // DUT
    instruction_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .MEM_SIZE(MEM_SIZE)
    ) dut (
        .address(tb_address),
        .instruction(tb_instruction)
    );

    // Instrucciones esperadas
    logic [31:0] expected [0:9];

    initial begin
        expected[0]  = 32'h00500093;
        expected[1]  = 32'h00300113;
        expected[2]  = 32'h002081b3;
        expected[3]  = 32'h40218233;
        expected[4]  = 32'h00302023;
        expected[5]  = 32'h00002283;
        expected[6]  = 32'hfff08093;
        expected[7]  = 32'h00008463;
        expected[8]  = 32'hff9ff06f;
        expected[9]  = 32'h0000006f;
    end

    initial begin
        $dumpfile("instruction_memory_rv32i_tb.vcd");
        $dumpvars(0, instruction_memory_rv32i_tb);
    end

    integer i;

    initial begin
        $display("\n---------------------------------------------------------");
        $display("  Probando Instruction Memory con programa RV32I básico");
        $display("---------------------------------------------------------\n");

        // Leer las primeras 10 instrucciones
        for (i=0; i<10; i++) begin
            tb_address = i * 4;
            #5;

            $display("PC=0x%08h | idx=%0d | instr=0x%08h | %s",
                     tb_address, tb_address[9:2], tb_instruction,
                     (tb_instruction == expected[i]) ? "OK" : "ERROR");
        end

        // Dirección no alineada
        tb_address = 32'h00000002;
        #5;
        $display("\nDireccion no alineada (0x2) → idx=%0d → instr=0x%08h",
                  tb_address[9:2], tb_instruction);

        // Dirección fuera de rango
        tb_address = 32'h00000400;
        #5;
        $display("Direccion fuera de rango (0x400) → idx=%0d → instr=0x%08h",
                  tb_address[9:2], tb_instruction);

        $display("\n---------------------------------------------------------\n");

        #10;
        $finish;
    end

endmodule
