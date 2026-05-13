module adder #(
    parameter N = 32
) (
    input logic [N-1:0] in1,
    input logic [N-1:0] in2,
    output logic [N-1:0] out
);
    always_comb begin
        out = in1 + in2;
    end

    // assign out = in1 + in2;
endmodule