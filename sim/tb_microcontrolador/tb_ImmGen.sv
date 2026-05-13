
`timescale 1ns / 1ps

module ImmGen_tb;

    logic [1:0] immSel;
    logic [31:0] instruction;
    logic [31:0] Imm;

    ImmGen imm (
        .instruction(instruction),
        .immSel(immSel),
        .Imm(Imm)
    );

    initial begin
        $dumpfile("ImmGen_waves.vcd");
        $dumpvars(0, ImmGen_tb);
    end

    initial begin
        instruction = 32'h7FF00000; 
        immSel = 2'b00;
        #10;
        $display("I-Type (Pos): Instr=0x%h, immSel=%b, Imm=0x%h", instruction, immSel, Imm);

        instruction = 32'h80000000; 
        immSel = 2'b00;
        #10;
        $display("I-Type (Neg): Instr=0x%h, immSel=%b, Imm=0x%h", instruction, immSel, Imm);

        instruction = 32'h0070A223; 
        immSel = 2'b01;
        #10;
        $display("S-Type (Pos): Instr=0x%h, immSel=%b, Imm=0x%h", instruction, immSel, Imm);

        instruction = 32'h7F000F80; 
        immSel = 2'b01;
        #10;
        $display("S-Type (Neg): Instr=0x%h, immSel=%b, Imm=0x%h", instruction, immSel, Imm);

        instruction = 32'h3F000F00; 
        immSel = 2'b10;
        #10;
        $display("B-Type (Pos): Instr=0x%h, immSel=%b, Imm=0x%h", instruction, immSel, Imm);

        instruction = 32'h80000080; 
        immSel = 2'b10;
        #10;
        $display("B-Type (Neg): Instr=0x%h, immSel=%b, Imm=0x%h", instruction, immSel, Imm);

        instruction = 32'h007FF0EF; 
        immSel = 2'b11;
        #10;
        $display("J-Type (Pos): Instr=0x%h, immSel=%b, Imm=0x%h", instruction, immSel, Imm);

        instruction = 32'hFFFFF00F; 
        immSel = 2'b11;
        #10;
        $display("J-Type (Neg): Instr=0x%h, immSel=%b, Imm=0x%h", instruction, immSel, Imm);

        immSel = 2'b10; 
        #10;
        $display("Default: Instr=0x%h, immSel=%b, Imm=0x%h", instruction, immSel, Imm);

        $finish;
    end

endmodule