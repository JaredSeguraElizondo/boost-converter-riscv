`timescale 1ns / 1ps

module gpio_peripheral (
    input  logic        clk_i,
    input  logic        rst_i,
    output logic [31:0] rdata_o,
    input  logic        boton_i
);

    localparam int DEBOUNCE_MAX = 1_000;

    logic [1:0]  sync_boton;
    logic [19:0] debounce_ctr;
    logic        boton_estable;

    // Sincronizador de doble flip-flop
    always_ff @(posedge clk_i) begin
        if (rst_i)
            sync_boton <= 2'b00;
        else
            sync_boton <= {sync_boton[0], boton_i};
    end

    // Debounce
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            debounce_ctr  <= 20'd0;
            boton_estable <= 1'b0;
        end else begin
            if (sync_boton[1] != boton_estable) begin
                if (debounce_ctr >= DEBOUNCE_MAX - 1) begin
                    boton_estable <= sync_boton[1];
                    debounce_ctr  <= 20'd0;
                end else begin
                    debounce_ctr <= debounce_ctr + 1'b1;
                end
            end else begin
                debounce_ctr <= 20'd0;
            end
        end
    end

    assign rdata_o = {31'd0, boton_estable};

endmodule
