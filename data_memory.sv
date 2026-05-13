
//   Memoria de datos (RAM) de 4 KB para el procesador RISC-V rv32i.
//   Almacena variables del programa: coeficientes del PI, errores
//   acumulados, valores intermedios de cálculo, etc.
//
//   Adaptada de data_memory.sv (Proyecto 2):
//     - Tamaño aumentado de 256 a 1024 words (4 KB)
//     - Indexación actualizada: address[11:2] (10 bits para 1024 posiciones)
//     - Rango de direcciones: 0x0000_2000 – 0x0000_2FFF
//     - Escritura síncrona, lectura asíncrona (combinacional)
//
// Conexión al bus:
//   Este módulo se conecta al bus de datos a través del address_decoder
//   y el read_mux. El address_decoder activa we_ram_o solo cuando la
//   dirección cae en el rango de RAM y el CPU indica escritura.
//
//   La dirección que llega (A) es la dirección completa de 32 bits
//   del CPU (ALUResultM). Solo usamos los bits [11:2] como índice interno,
//   lo cual cubre el offset de 0x000 a 0xFFF dentro del rango de RAM.
//   Los bits superiores ya fueron evaluados por el address_decoder.
// ============================================================================

module data_memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MEM_SIZE   = 1024          // 1024 words × 4 bytes = 4 KB
)(
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  WE,       // Write-enable (viene de we_ram_o)
    input  logic [ADDR_WIDTH-1:0] A,        // Dirección completa del bus
    input  logic [DATA_WIDTH-1:0] WD,       // Dato a escribir (WriteDataM)
    output logic [DATA_WIDTH-1:0] RD        // Dato leído (hacia read_mux)
);

    // ── Arreglo de memoria ──
    logic [DATA_WIDTH-1:0] mem [0:MEM_SIZE-1];

    // ── Índice para reset ──
    integer idx;

    // ── Escritura síncrona + reset síncrono ──
    always_ff @(posedge clk) begin
        if (reset) begin
            for (idx = 0; idx < MEM_SIZE; idx = idx + 1)
                mem[idx] <= {DATA_WIDTH{1'b0}};
        end
        else if (WE) begin
            mem[A[11:2]] <= WD;
        end
    end

    // ── Lectura asíncrona (combinacional) ──
    // A[11:2] → 10 bits → hasta 1024 posiciones
    // A[1:0]  → descartados (word-aligned)
    assign RD = mem[A[11:2]];

endmodule