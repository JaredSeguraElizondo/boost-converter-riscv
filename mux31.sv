
module mux31 #(
    parameter N = 32
)(
    input logic [N-1:0] a, b, c,
    input logic [1:0] sel,
    output logic [N-1:0] f
);
    assign f = (sel == 2'b00) ? a : 
               (sel == 2'b01) ? b : 
               (sel == 2'b10) ? c : '0;
endmodule