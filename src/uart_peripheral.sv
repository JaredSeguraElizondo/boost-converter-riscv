`timescale 1ns / 1ps

module uart_peripheral (
    input  logic        clk_cpu_i,
    input  logic        rst_cpu_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    input  logic        clk_uart_i,
    input  logic        rst_uart_i,

    input  logic        RsRx,
    output logic        RsTx
);

    logic       reg_send;
    logic       reg_new_rx;
    logic [7:0] reg_data_tx;
    logic [7:0] reg_data_rx;

    logic       tx_start_uart;
    logic       tx_rdy_uart;
    logic       rx_rdy_uart;
    logic [7:0] data_in_uart;
    logic [7:0] data_out_uart;


    UART uart_core_inst (
        .clk         (clk_uart_i),
        .reset       (rst_uart_i),
        .tx_start    (tx_start_uart),
        .tx_rdy      (tx_rdy_uart),
        .rx_data_rdy (rx_rdy_uart),
        .data_in     (data_in_uart),
        .data_out    (data_out_uart),
        .rx          (RsRx),
        .tx          (RsTx)
    );

    // Sincronizador de 2 etapas: reg_send (dominio CPU) → dominio UART
    // reg_send se mantiene alto hasta que sync_send[1] lo confirma,
    // garantizando captura aunque clk_uart sea más lenta que clk_cpu.
    logic [1:0] sync_send;

    always_ff @(posedge clk_uart_i) begin
        if (rst_uart_i) sync_send <= 2'b00;
        else            sync_send <= {sync_send[0], reg_send};
    end

    // tx_start_uart es un pulso de 1 ciclo UART en flanco de subida de sync_send
    assign tx_start_uart = sync_send[0] & ~sync_send[1];

    // ACK de vuelta al dominio CPU: cuando sync_send[1] sube, reg_send fue capturado
    logic [2:0] sync_send_ack;
    always_ff @(posedge clk_cpu_i) begin
        if (rst_cpu_i) sync_send_ack <= 3'b000;
        else           sync_send_ack <= {sync_send_ack[1:0], sync_send[1]};
    end
    logic send_ack_pulse;
    assign send_ack_pulse = sync_send_ack[1] & ~sync_send_ack[2];

    always_ff @(posedge clk_uart_i) begin
        if (rst_uart_i) data_in_uart <= 8'h00;
        else            data_in_uart <= reg_data_tx;
    end

    logic [2:0] sync_tx_rdy;
    logic       tx_rdy_pulse;

    always_ff @(posedge clk_cpu_i) begin
        if (rst_cpu_i) sync_tx_rdy <= 3'b000;
        else           sync_tx_rdy <= {sync_tx_rdy[1:0], tx_rdy_uart};
    end

    assign tx_rdy_pulse = sync_tx_rdy[1] & ~sync_tx_rdy[2];

    logic [2:0] sync_rx_rdy;
    logic       rx_rdy_pulse;

    always_ff @(posedge clk_cpu_i) begin
        if (rst_cpu_i) sync_rx_rdy <= 3'b000;
        else           sync_rx_rdy <= {sync_rx_rdy[1:0], rx_rdy_uart};
    end

    assign rx_rdy_pulse = sync_rx_rdy[1] & ~sync_rx_rdy[2];

    logic tx_busy;

    always_ff @(posedge clk_cpu_i) begin
        if (rst_cpu_i) begin
            reg_send    <= 1'b0;
            reg_new_rx  <= 1'b0;
            reg_data_tx <= 8'h00;
            reg_data_rx <= 8'h00;
            tx_busy     <= 1'b0;
        end else begin
            // Bajar reg_send cuando el dominio UART confirmó que lo capturó
            if (send_ack_pulse) begin
                reg_send <= 1'b0;
            end
            // tx_busy baja cuando la transmisión termina (tx_rdy_pulse)
            if (tx_rdy_pulse) begin
                tx_busy  <= 1'b0;
            end

            if (rx_rdy_pulse) begin
                reg_new_rx  <= 1'b1;
                reg_data_rx <= data_out_uart;
            end

            if (write_enable_i) begin
                case (addr_i)
                    2'b00: begin 
                        if (wdata_i[0]) begin
                            reg_send <= 1'b1;
                            tx_busy  <= 1'b1;
                        end
                        if (wdata_i[1]) reg_new_rx <= 1'b0;
                    end
                    2'b01: reg_data_tx <= wdata_i[7:0]; 
                    default: ;
                endcase
            end
        end
    end

    always_comb begin
        unique case (addr_i)
            2'b00:   rdata_o = {29'd0, tx_busy, reg_new_rx, reg_send};
            2'b01:   rdata_o = {24'd0, reg_data_tx};
            2'b10:   rdata_o = {24'd0, reg_data_rx};
            default: rdata_o = 32'h0;
        endcase
    end

endmodule