// Descripción:
//   Memoria de programa (ROM) de 8 KB para el procesador RISC-V rv32i.
//   Almacena las instrucciones del programa de control PI y se inicializa
//   desde un archivo .hex generado por el ensamblador.
//
//   Adaptada de instruction_memory.sv (Proyecto 2):
//     - Tamaño aumentado de 256 a 2048 words (8 KB)
//     - Indexación actualizada: address[12:2] (11 bits para 2048 posiciones)
//     - Rango de direcciones: 0x0000_0000 – 0x0000_1FFF
//     - Lectura puramente combinacional (asíncrona)
//
// Nota:
//   El CPU envía ProgAddress_o (el PC) como dirección byte-addressed.
//   Se descartan los 2 bits inferiores porque cada instrucción ocupa
//   4 bytes (word-aligned), y se usan los bits [12:2] como índice.
//
//   Cambiar el path del $readmemh al archivo .hex del programa final.
// ============================================================================

module instruction_memory #(
    parameter DATA_WIDTH    = 32,
    parameter ADDRESS_WIDTH = 32,
    parameter MEM_SIZE      = 2048       // 2048 words × 4 bytes = 8 KB
)(
    input  logic [ADDRESS_WIDTH-1:0] address,
    output logic [DATA_WIDTH-1:0]    instruction
);

    // ── Arreglo de memoria ──
    logic [DATA_WIDTH-1:0] IM [0:MEM_SIZE-1];

    // ── Inicialización desde archivo hex ──
    initial begin
        $readmemh("programa.hex", IM);
    end

    // ── Lectura combinacional (asíncrona) ──
    // address[12:2] → 11 bits → hasta 2048 posiciones
    // address[1:0]  → descartados (word-aligned)
    assign instruction = IM[address[12:2]];

endmodule