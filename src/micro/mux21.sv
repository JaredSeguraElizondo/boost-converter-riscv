module mux21 #(
    parameter N = 32
) (
    input logic [N-1:0] a, b,
    input logic sel,
    output logic [N-1:0] f
);

    assign f = sel ? b : a;
endmodule