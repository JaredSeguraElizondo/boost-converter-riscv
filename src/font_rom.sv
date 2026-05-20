`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/01/2026 04:23:45 PM
// Design Name: 
// Module Name: romfont
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

module font_rom (
    input  logic [3:0] char_code_i, 
    input  logic [2:0] row_i,       
    output logic [7:0] pixels_o     
);
    always_comb begin
        case (char_code_i)
            4'd0: case(row_i) 0: pixels_o=8'h3C; 1: pixels_o=8'h42; 2: pixels_o=8'h42; 3: pixels_o=8'h42; 4: pixels_o=8'h42; 5: pixels_o=8'h42; 6: pixels_o=8'h42; 7: pixels_o=8'h3C; endcase
            4'd1: case(row_i) 0: pixels_o=8'h08; 1: pixels_o=8'h18; 2: pixels_o=8'h08; 3: pixels_o=8'h08; 4: pixels_o=8'h08; 5: pixels_o=8'h08; 6: pixels_o=8'h08; 7: pixels_o=8'h1C; endcase
            4'd2: case(row_i) 0: pixels_o=8'h3C; 1: pixels_o=8'h42; 2: pixels_o=8'h02; 3: pixels_o=8'h0C; 4: pixels_o=8'h10; 5: pixels_o=8'h20; 6: pixels_o=8'h40; 7: pixels_o=8'h7E; endcase
            4'd3: case(row_i) 0: pixels_o=8'h3C; 1: pixels_o=8'h42; 2: pixels_o=8'h02; 3: pixels_o=8'h1C; 4: pixels_o=8'h02; 5: pixels_o=8'h02; 6: pixels_o=8'h42; 7: pixels_o=8'h3C; endcase
            4'd4: case(row_i) 0: pixels_o=8'h0C; 1: pixels_o=8'h14; 2: pixels_o=8'h24; 3: pixels_o=8'h44; 4: pixels_o=8'h7E; 5: pixels_o=8'h04; 6: pixels_o=8'h04; 7: pixels_o=8'h04; endcase
            4'd5: case(row_i) 0: pixels_o=8'h7E; 1: pixels_o=8'h40; 2: pixels_o=8'h40; 3: pixels_o=8'h7C; 4: pixels_o=8'h02; 5: pixels_o=8'h02; 6: pixels_o=8'h42; 7: pixels_o=8'h3C; endcase
            4'd6: case(row_i) 0: pixels_o=8'h3C; 1: pixels_o=8'h40; 2: pixels_o=8'h40; 3: pixels_o=8'h7C; 4: pixels_o=8'h42; 5: pixels_o=8'h42; 6: pixels_o=8'h42; 7: pixels_o=8'h3C; endcase
            4'd7: case(row_i) 0: pixels_o=8'h7E; 1: pixels_o=8'h02; 2: pixels_o=8'h04; 3: pixels_o=8'h08; 4: pixels_o=8'h10; 5: pixels_o=8'h20; 6: pixels_o=8'h20; 7: pixels_o=8'h20; endcase
            4'd8: case(row_i) 0: pixels_o=8'h3C; 1: pixels_o=8'h42; 2: pixels_o=8'h42; 3: pixels_o=8'h3C; 4: pixels_o=8'h42; 5: pixels_o=8'h42; 6: pixels_o=8'h42; 7: pixels_o=8'h3C; endcase
            4'd9: case(row_i) 0: pixels_o=8'h3C; 1: pixels_o=8'h42; 2: pixels_o=8'h42; 3: pixels_o=8'h42; 4: pixels_o=8'h3E; 5: pixels_o=8'h02; 6: pixels_o=8'h02; 7: pixels_o=8'h3C; endcase
            4'd10: case(row_i) 0: pixels_o=8'h42; 1: pixels_o=8'h42; 2: pixels_o=8'h42; 3: pixels_o=8'h42; 4: pixels_o=8'h42; 5: pixels_o=8'h24; 6: pixels_o=8'h18; 7: pixels_o=8'h00; endcase
            4'd11: case(row_i) 0: pixels_o=8'h00; 1: pixels_o=8'h00; 2: pixels_o=8'h00; 3: pixels_o=8'h00; 4: pixels_o=8'h00; 5: pixels_o=8'h00; 6: pixels_o=8'h18; 7: pixels_o=8'h18; endcase
            // NUEVO: Símbolo '%' (Código 13)
            4'd13: case(row_i) 0: pixels_o=8'h62; 1: pixels_o=8'h64; 2: pixels_o=8'h08; 3: pixels_o=8'h10; 4: pixels_o=8'h20; 5: pixels_o=8'h26; 6: pixels_o=8'h46; 7: pixels_o=8'h00; endcase
            default: pixels_o = 8'h00;
        endcase
    end
endmodule