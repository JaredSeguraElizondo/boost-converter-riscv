`timescale 1ns / 1ps
module gpio_peripheral (
    input  logic        clk_i,
    input  logic        rst_i,
    output logic [31:0] rdata_o,
    input  logic        boton_i,
    input  logic [1:0]  sw_i       // [FIX] switches para freq_sel del PWM
);
    // Debounce de 20 ms a 100 MHz
    localparam int DEBOUNCE_MAX = 2_000_000;
    logic [1:0]  sync_boton;
    logic [20:0] debounce_ctr;
    logic        boton_estable;

    // Sincronizador de doble flip-flop para el botón
    always_ff @(posedge clk_i) begin
        if (rst_i)
            sync_boton <= 2'b00;
        else
            sync_boton <= {sync_boton[0], boton_i};
    end

    // Debounce
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            debounce_ctr  <= '0;
            boton_estable <= 1'b0;
        end else begin
            if (sync_boton[1] != boton_estable) begin
                if (debounce_ctr >= DEBOUNCE_MAX - 1) begin
                    boton_estable <= sync_boton[1];
                    debounce_ctr  <= '0;
                end else begin
                    debounce_ctr <= debounce_ctr + 1'b1;
                end
            end else begin
                debounce_ctr <= '0;
            end
        end
    end

    // bit 0 = botón, bits [2:1] = switches para freq_sel
    assign rdata_o = {29'd0, sw_i, boton_estable};

endmodule