`timescale 1ns / 1ps
module vga_mmio_wrapper (
    input  logic        clk_100mhz,  
    input  logic        rst,
    
    // Interfaz de conexión MMIO con el procesador
    input  logic        we_i, 
    input  logic [3:0]  addr_i, 
    input  logic [31:0] dat_i, 
    output logic [31:0] dat_o, 
    // Interfaz Física VGA
    input  logic        clk_25mhz,  
    output logic        vga_hsync, 
    output logic        vga_vsync, 
    output logic [3:0]  vga_r,    
    output logic [3:0]  vga_g,   
    output logic [3:0]  vga_b   
);
    // =========================================================================
    // 1. Registros 32 bits y VRAM
    // =========================================================================
    logic [31:0] reg_ctrl; // Offset 0x00: Control (Bit 0 = Enable)
    logic [31:0] reg_volt; // Offset 0x08: Valor a mostrar de Voltaje
    logic [31:0] reg_pwm;  // Offset 0x0C: Valor a mostrar de PWM
    
    logic [9:0]  x_write_ptr; // Puntero circular interno de hardware para la VRAM

    // Lógica de Escritura 
    always_ff @(posedge clk_100mhz) begin 
        if (rst) begin 
            reg_ctrl    <= 32'd0;
            reg_volt    <= 32'd0;
            reg_pwm     <= 32'd0;
            x_write_ptr <= 10'd0;
        end else if (we_i) begin  
            if (addr_i == 4'h0) begin
                reg_ctrl[0] <= dat_i[0];
            end else if (addr_i == 4'h4) begin
                if (x_write_ptr == 10'd639) x_write_ptr <= 10'd0;
                else x_write_ptr <= x_write_ptr + 1'b1; 
            end else if (addr_i == 4'h8) begin 
                reg_volt[11:0] <= dat_i[11:0];
            end else if (addr_i == 4'hC) begin 
                reg_pwm[11:0]  <= dat_i[11:0];
            end
        end
    end

    // Lógica de Lectura  
    always_comb begin
        dat_o = 32'd0;
        case (addr_i)
            4'h0: dat_o = {31'd0, reg_ctrl[0]};
            4'h8: dat_o = {20'd0, reg_volt[11:0]};
            4'hC: dat_o = {20'd0, reg_pwm[11:0]};
            default: dat_o = 32'd0;
        endcase
    end

    // =========================================================================
    // Memoria de Video (VRAM) con escala 0-28 V
    //   Fondo de escala 28V → margen visual de ~4V sobre la etiqueta 24V
    //   Fórmula: y_pixel = 460 - (valor * 103 >> 10)
    //   460 / (4095 * 28 / 25) * 1024 ≈ 103  →  error máximo ~0.4 px
    // =========================================================================
    logic [9:0] vram [0:639]; 
    logic [9:0] vram_read_data;

    logic [21:0] y_temp;
    logic [9:0]  y_scaled;

    always_comb begin
        y_temp   = dat_i[11:0] * 22'd103;   // máx: 4095*103 = 421785 → cabe en 19 bits
        y_scaled = 10'd460 - y_temp[19:10];  // >> 10
    end

    always_ff @(posedge clk_100mhz) begin
        if (we_i && addr_i == 4'h4) begin
            vram[x_write_ptr] <= y_scaled;
        end
    end

    // =========================================================================
    // 2. Sincronismo VGA
    // =========================================================================
    logic [9:0] h_count;
    logic [9:0] v_count;
    logic display_enable;

    always_ff @(posedge clk_25mhz) begin
        if (rst) begin 
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else begin   
            if (h_count == 10'd799) begin
                h_count <= 10'd0;
                if (v_count == 10'd524) v_count <= 10'd0; 
                else v_count <= v_count + 1'b1;
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    assign vga_hsync = (h_count >= 656 && h_count < 752) ? 1'b0 : 1'b1;
    assign vga_vsync = (v_count >= 490 && v_count < 492) ? 1'b0 : 1'b1;
    
    assign display_enable = (h_count < 640 && v_count < 480) && reg_ctrl[0];
    assign vram_read_data = vram[h_count];

    // =========================================================================
    // 3. Generación de Texto en Hardware
    // =========================================================================
    logic [3:0] d3, d2, d1, d0; // Dígitos de Voltaje
    logic [3:0] p3, p2, p1, p0; // Dígitos de PWM

    bin2bcd u_bcd_volt (
        .bin_i(reg_volt[11:0]),
        .thousands_o(d3), .hundreds_o(d2), .tens_o(d1), .ones_o(d0)
    );
    bin2bcd u_bcd_pwm (
        .bin_i(reg_pwm[11:0]),
        .thousands_o(p3), .hundreds_o(p2), .tens_o(p1), .ones_o(p0)
    );

    // -------------------------------------------------------------------------
    // Cajas de texto dinámicas (Voltaje y PWM)
    // -------------------------------------------------------------------------
    logic is_text_box;
    assign is_text_box = (h_count >= 10'd520 && h_count < 10'd600) && 
                         (v_count >= 10'd20  && v_count < 10'd36);

    logic is_pwm_box;
    assign is_pwm_box  = (h_count >= 10'd520 && h_count < 10'd600) && 
                         (v_count >= 10'd40  && v_count < 10'd56);

    // -------------------------------------------------------------------------
    // Etiquetas fijas del eje Y - fondo de escala 28V, etiquetas en 0/6/12/18/24V
    //
    //   Posición Y = 460 - (V * 460 / 28)
    //   24V → Y = 460 - 394 =  66  → banda v_count: 58-74
    //   18V → Y = 460 - 296 = 164  → banda v_count: 156-172
    //   12V → Y = 460 - 197 = 263  → banda v_count: 255-271
    //    6V → Y = 460 -  99 = 361  → banda v_count: 353-369
    //    0V → Y = 460             → banda v_count: 452-468
    // -------------------------------------------------------------------------
    logic is_lbl_24, is_lbl_18, is_lbl_12, is_lbl_06, is_lbl_00;

    assign is_lbl_24 = (v_count >= 10'd58  && v_count < 10'd74);
    assign is_lbl_18 = (v_count >= 10'd156 && v_count < 10'd172);
    assign is_lbl_12 = (v_count >= 10'd255 && v_count < 10'd271);
    assign is_lbl_06 = (v_count >= 10'd353 && v_count < 10'd369);
    assign is_lbl_00 = (v_count >= 10'd452 && v_count < 10'd468);

    logic is_label_box;
    assign is_label_box = (h_count >= 10'd25 && h_count < 10'd89) && 
                          (is_lbl_24 || is_lbl_18 || is_lbl_12 || is_lbl_06 || is_lbl_00);

    // -------------------------------------------------------------------------
    // Multiplexión de coordenadas e índices de carácter
    // -------------------------------------------------------------------------
    logic [2:0] active_char_index; 
    logic [2:0] font_row;   
    logic [2:0] font_col;

    assign active_char_index = (is_text_box || is_pwm_box) ? ((h_count - 10'd520) >> 4) :
                               is_label_box                 ? ((h_count - 10'd25)  >> 4) : 3'd0;

    assign font_col = (is_text_box || is_pwm_box) ? (((h_count - 10'd520) >> 1) & 3'b111) :
                      is_label_box                 ? (((h_count - 10'd25)  >> 1) & 3'b111) : 3'd0;

    assign font_row = is_text_box ? (((v_count - 10'd20)  >> 1) & 3'b111) :
                      is_pwm_box  ? (((v_count - 10'd40)  >> 1) & 3'b111) :
                      is_lbl_24   ? (((v_count - 10'd58)  >> 1) & 3'b111) :
                      is_lbl_18   ? (((v_count - 10'd156) >> 1) & 3'b111) :
                      is_lbl_12   ? (((v_count - 10'd255) >> 1) & 3'b111) :
                      is_lbl_06   ? (((v_count - 10'd353) >> 1) & 3'b111) :
                      is_lbl_00   ? (((v_count - 10'd452) >> 1) & 3'b111) : 3'd0;

    // -------------------------------------------------------------------------
    // Códigos de carácter
    // -------------------------------------------------------------------------
    logic [3:0] char_code_v, char_code_p, char_code_l, char_code;

    // Voltaje dinámico (d3..d0 + 'V')
    always_comb begin
        case (active_char_index)
            3'd0: char_code_v = d3;
            3'd1: char_code_v = d2;  
            3'd2: char_code_v = d1; 
            3'd3: char_code_v = d0; 
            3'd4: char_code_v = 4'd10; // 'V'
            default: char_code_v = 4'd12; // ' '
        endcase
    end

    // PWM dinámico (" NNN%")
    always_comb begin
        case (active_char_index)
            3'd0: char_code_p = 4'd12; // ' '
            3'd1: char_code_p = p2;
            3'd2: char_code_p = p1;
            3'd3: char_code_p = p0;
            3'd4: char_code_p = 4'd13; // '%'
            default: char_code_p = 4'd12;
        endcase
    end

    // Etiquetas fijas eje Y
    always_comb begin
        if (is_lbl_24) begin
            // "24V "
            case (active_char_index)
                3'd0: char_code_l = 4'd2;   // '2'
                3'd1: char_code_l = 4'd4;   // '4'
                3'd2: char_code_l = 4'd10;  // 'V'
                3'd3: char_code_l = 4'd12;  // ' '
                default: char_code_l = 4'd12;
            endcase
        end else if (is_lbl_18) begin
            // "18V "
            case (active_char_index)
                3'd0: char_code_l = 4'd1;   // '1'
                3'd1: char_code_l = 4'd8;   // '8'
                3'd2: char_code_l = 4'd10;  // 'V'
                3'd3: char_code_l = 4'd12;  // ' '
                default: char_code_l = 4'd12;
            endcase
        end else if (is_lbl_12) begin
            // "12V "
            case (active_char_index)
                3'd0: char_code_l = 4'd1;   // '1'
                3'd1: char_code_l = 4'd2;   // '2'
                3'd2: char_code_l = 4'd10;  // 'V'
                3'd3: char_code_l = 4'd12;  // ' '
                default: char_code_l = 4'd12;
            endcase
        end else if (is_lbl_06) begin
            // " 6V "
            case (active_char_index)
                3'd0: char_code_l = 4'd12;  // ' '
                3'd1: char_code_l = 4'd6;   // '6'
                3'd2: char_code_l = 4'd10;  // 'V'
                3'd3: char_code_l = 4'd12;  // ' '
                default: char_code_l = 4'd12;
            endcase
        end else begin
            // " 0V "  (is_lbl_00)
            case (active_char_index)
                3'd0: char_code_l = 4'd12;  // ' '
                3'd1: char_code_l = 4'd0;   // '0'
                3'd2: char_code_l = 4'd10;  // 'V'
                3'd3: char_code_l = 4'd12;  // ' '
                default: char_code_l = 4'd12;
            endcase
        end
    end

    assign char_code = is_text_box  ? char_code_v : 
                       is_pwm_box   ? char_code_p : 
                       is_label_box ? char_code_l : 4'd12;

    // -------------------------------------------------------------------------
    // ROM de fuente
    // -------------------------------------------------------------------------
    logic [7:0] font_pixels;

    font_rom u_font (
        .char_code_i(char_code),
        .row_i(font_row),
        .pixels_o(font_pixels)
    );

    // Sin punto decimal (escala entera)
    logic is_manual_dot;
    assign is_manual_dot = 1'b0;

    logic is_text_pixel;
    assign is_text_pixel = ((is_text_box || is_pwm_box || is_label_box) && 
                             font_pixels[7 - font_col]) || is_manual_dot;

    // =========================================================================
    // 4. Multiplexor de Capas Visuales
    // =========================================================================
    logic is_signal, is_axis, is_grid;

    assign is_signal = (v_count == vram_read_data)         ||
                       (v_count == vram_read_data + 10'd1) ||
                       (v_count == vram_read_data - 10'd1);

    // Ejes de 3 píxeles de ancho
    assign is_axis = (h_count >= 10'd19 && h_count <= 10'd21) ||
                     (v_count >= 10'd459 && v_count <= 10'd461);

    // Grid: líneas verticales cada 64px desde X=20; horizontales cada 64px desde Y=460
    assign is_grid = (((h_count >= 10'd20) && ((h_count - 10'd20) % 64 == 0))  ||
                      ((v_count <= 10'd460) && ((10'd460 - v_count) % 64 == 0)));

    always_comb begin 
        if (display_enable) begin
            if (is_text_pixel) begin
                vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;  // Blanco
            end else if (is_signal) begin
                vga_r = 4'h0; vga_g = 4'hF; vga_b = 4'h0;  // Verde
            end else if (is_axis) begin
                vga_r = 4'hA; vga_g = 4'hA; vga_b = 4'hA;  // Gris claro
            end else if (is_grid) begin
                vga_r = 4'h2; vga_g = 4'h3; vga_b = 4'h2;  // Gris oscuro
            end else begin
                vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;  // Negro
            end
        end else begin
            vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
        end
    end

endmodule
