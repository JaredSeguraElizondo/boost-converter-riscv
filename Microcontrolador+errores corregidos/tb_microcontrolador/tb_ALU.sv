// ============================================================================
// tb_ALU_proyecto3.sv
// Cambios respecto al TB anterior:
//   [FIX5] Agrega puerto Sub a la instancia del DUT
//   [NEW]  Agrega caso SRAI (usado en assembly: srai x6, x4, 10)
//   [NEW]  Agrega caso SUB con Sub=1 (usado en: sub x2, x1, x7)
// ============================================================================

`timescale 1ns / 1ps

module tb_ALU_proyecto3;

    logic [31:0] operand1;
    logic [31:0] operand2;
    logic [2:0]  ALUControl;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic        Sub;       // [FIX5]
    logic [31:0] result;
    logic        zero;

    ALU uut (
        .operand1  (operand1),
        .operand2  (operand2),
        .ALUControl(ALUControl),
        .funct3    (funct3),
        .funct7    (funct7),
        .Sub       (Sub),   // [FIX5]
        .result    (result),
        .zero      (zero)
    );

    task check(
        input string    op_name,
        input logic [31:0] expected
    );
        #1;
        if (result === expected)
            $display("PASS  %-10s op1=%08h op2=%08h → %08h", op_name, operand1, operand2, result);
        else
            $display("FAIL  %-10s op1=%08h op2=%08h → %08h (esperado %08h)",
                     op_name, operand1, operand2, result, expected);
    endtask

    initial begin
        $dumpfile("tb_ALU_proyecto3.vcd");
        $dumpvars(0, tb_ALU_proyecto3);
        Sub = 0;

        $display("=== Testbench ALU (Proyecto 3) ===");

        // ── ADD (Sub=0) ──
        ALUControl=3'b000; funct3=3'b000; funct7=7'b0000000; Sub=0;
        operand1=32'h5; operand2=32'h3;
        check("ADD 5+3", 32'h8);

        operand1=32'hFFFFFFFF; operand2=32'h1;
        check("ADD ovf", 32'h0);

        operand1=32'h0; operand2=32'h0;
        check("ADD 0+0", 32'h0);

        // ── SUB (Sub=1) — usado en: sub x2, x1, x7 ──
        ALUControl=3'b000; funct3=3'b000; funct7=7'b0100000; Sub=1;
        operand1=32'h0CCD; operand2=32'h0800; // Vref=3277, adc=2048
        check("SUB vref-adc", 32'h04CD);       // e_n = 1229

        operand1=32'h0; operand2=32'h1;
        check("SUB 0-1", 32'hFFFFFFFF);         // negativo

        operand1=32'h0800; operand2=32'h0CCD;
        check("SUB neg e_n", 32'hFFFFF333);      // ADC > Vref

        // ── SRAI (funct7[5]=1) — usado en: srai x6, x4, 10 ──
        // assembly: srai x6, x4, 10 → duty = u_acc >> 10
        ALUControl=3'b101; funct3=3'b101; funct7=7'b0100000; Sub=0;
        operand1=32'h00019000; operand2=32'h0A;  // u_acc=102400, shift=10
        check("SRAI 102400>>10", 32'h64);         // = 100 (duty max)

        operand1=32'h00000400; operand2=32'h0A;  // u_acc=1024, shift=10
        check("SRAI 1024>>10", 32'h1);            // = 1

        operand1=32'hFFFFF000; operand2=32'h0A;  // negativo
        check("SRAI neg>>10", 32'hFFFFFFFC);      // signo extendido

        // ── SRLI (funct7[5]=0) — misma ALUControl ──
        ALUControl=3'b101; funct3=3'b101; funct7=7'b0000000; Sub=0;
        operand1=32'h80000000; operand2=32'h4;
        check("SRLI>>4", 32'h08000000);           // sin extension de signo

        // ── SLLI — usado en: slli x17, x17, 20 ──
        ALUControl=3'b001; funct3=3'b001; funct7=7'b0; Sub=0;
        operand1=32'h00000001; operand2=32'h14;  // shift 20
        check("SLLI<<20", 32'h00100000);

        operand1=32'h00000FFF; operand2=32'h14;  // mascarar 12 bits bajos
        check("SLLI<<20 mask", 32'hFFF00000);

        // ── ANDI — usado en: andi x8, x8, 2 ──
        ALUControl=3'b111; funct3=3'b111; funct7=7'b0; Sub=0;
        operand1=32'h00000002; operand2=32'h00000002;
        check("ANDI 2&2", 32'h2);
        operand1=32'h00000001; operand2=32'h00000002;
        check("ANDI 1&2", 32'h0);

        // ── OR ──
        ALUControl=3'b110; funct3=3'b110; funct7=7'b0; Sub=0;
        operand1=32'h00001111; operand2=32'h11110000;
        check("OR", 32'h11111111);

        // ── AND ──
        ALUControl=3'b111; funct3=3'b111; funct7=7'b0; Sub=0;
        operand1=32'hFFFFFFFF; operand2=32'hAAAAAAAA;
        check("AND", 32'hAAAAAAAA);

        // ── Zero flag ──
        ALUControl=3'b000; funct3=3'b000; funct7=7'b0100000; Sub=1;
        operand1=32'h5; operand2=32'h5;
        #1;
        if (zero !== 1'b1) $display("FAIL  zero flag (5-5 deberia ser zero=1, got %b)", zero);
        else                $display("PASS  zero flag  5-5=0 zero=1");

        $display("=== Fin testbench ALU ===");
        $finish;
    end

endmodule