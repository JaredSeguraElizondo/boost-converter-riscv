`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/01/2026 04:22:41 PM
// Design Name: 
// Module Name: binbcd
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

`timescale 1ns / 1ps

module bin2bcd (
    input  logic [11:0] bin_i,       
    output logic [3:0]  thousands_o, 
    output logic [3:0]  hundreds_o,  
    output logic [3:0]  tens_o,      
    output logic [3:0]  ones_o       
);
    integer i;
    logic [27:0] shift; 

    always_comb begin
        shift = 28'd0;
        shift[11:0] = bin_i;

        for (i = 0; i < 12; i = i + 1) begin
            if (shift[15:12] >= 5) shift[15:12] = shift[15:12] + 3;
            if (shift[19:16] >= 5) shift[19:16] = shift[19:16] + 3;
            if (shift[23:20] >= 5) shift[23:20] = shift[23:20] + 3;
            if (shift[27:24] >= 5) shift[27:24] = shift[27:24] + 3;
            
            shift = shift << 1;
        end

        thousands_o = shift[27:24];
        hundreds_o  = shift[23:20];
        tens_o      = shift[19:16];
        ones_o      = shift[15:12];
    end
endmodule