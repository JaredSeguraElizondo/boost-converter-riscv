module pc #(
    parameter N = 32
) (
    input  logic clk,
    input  logic reset,
    input  logic StallF,              // Stall desde hazard unit
    input  logic [N-1:0] pc_in,       // Dirección siguiente
    output logic [N-1:0] pc_out       // Dirección actual
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out <= {N{1'b0}};
        end else if (!StallF) begin
            pc_out <= pc_in;         // Solo se actualiza si no hay stall
        end
        // Si StallF = 1, mantiene pc_out (stall)
    end
endmodule