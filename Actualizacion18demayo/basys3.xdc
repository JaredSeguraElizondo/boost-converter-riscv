# ==============================================================================
# Constraints para top_microcontroller -- Basys 3
# (Artix-7 XC7A35T-1CPG236C)
# ==============================================================================

# Verificar que los nombres de puertos coincidan exactamente
# con los del modulo top_microcontroller.
# ==============================================================================


# ==============================================================================
# RELOJ PRINCIPAL (100 MHz, oscilador onboard)
# ==============================================================================
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk_100mhz]
create_clock -period 10.000 -name sys_clk [get_ports clk_100mhz]


# ==============================================================================
# RESET (boton central btnC, activo alto)
# ==============================================================================
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports rst_btn]


# ==============================================================================
# BOTON DE ENVIO UART (btnU, activo alto)
# Cambiar el pin si se prefiere otro boton:
# btnD = U17, btnL = W19, btnR = T17
# ==============================================================================
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports btn_send]


# ==============================================================================
# PWM (salida hacia el gate driver del boost converter)
# Asignado a JB[0] (PMOD JB, pin 1, banco 34).
# NO usar JA porque comparte banco 35 con el XADC
# (conflicto de voltaje).
#
# Alternativas en JB:
# JB[1]=A16, JB[2]=B15, JB[3]=B16
# ==============================================================================
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports pwm_o]


# ==============================================================================
# UART (USB-UART del Basys 3, conector micro-USB)
# ==============================================================================
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports RsRx]
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports RsTx]


# ==============================================================================
# VGA (conector VGA del Basys 3, 4 bits por canal)
# ==============================================================================

# HSYNC y VSYNC
set_property -dict { PACKAGE_PIN P19 IOSTANDARD LVCMOS33 } [get_ports hsync_o]
set_property -dict { PACKAGE_PIN R19 IOSTANDARD LVCMOS33 } [get_ports vsync_o]

# Rojo [3:0]
set_property -dict { PACKAGE_PIN G19 IOSTANDARD LVCMOS33 } [get_ports {vga_red_o[0]}]
set_property -dict { PACKAGE_PIN H19 IOSTANDARD LVCMOS33 } [get_ports {vga_red_o[1]}]
set_property -dict { PACKAGE_PIN J19 IOSTANDARD LVCMOS33 } [get_ports {vga_red_o[2]}]
set_property -dict { PACKAGE_PIN N19 IOSTANDARD LVCMOS33 } [get_ports {vga_red_o[3]}]

# Verde [3:0]
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports {vga_grn_o[0]}]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {vga_grn_o[1]}]
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports {vga_grn_o[2]}]
set_property -dict { PACKAGE_PIN D17 IOSTANDARD LVCMOS33 } [get_ports {vga_grn_o[3]}]

# Azul [3:0]
set_property -dict { PACKAGE_PIN N18 IOSTANDARD LVCMOS33 } [get_ports {vga_blu_o[0]}]
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports {vga_blu_o[1]}]
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports {vga_blu_o[2]}]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports {vga_blu_o[3]}]


# ==============================================================================
# XADC -- Canal VAUX6 (header JXADC del Basys 3)
#
# El banco 35 del Basys 3 tiene VCCO = 3.3V,
# por lo que se usa LVCMOS33.
#
# Vivado auto-asigna LVCMOS18 a pines XADC,
# lo cual causa conflicto con el VCCO real del banco.
#
# Se fuerza LVCMOS33 para evitarlo.
#
# JXADC pin 1 = VAUXP6 = J3
# JXADC pin 7 = VAUXN6 = K3
# ==============================================================================
set_property -dict { PACKAGE_PIN J3 IOSTANDARD LVCMOS33 } [get_ports vauxp6]
set_property -dict { PACKAGE_PIN K3 IOSTANDARD LVCMOS33 } [get_ports vauxn6]


# ==============================================================================
# CONFIGURACION ADICIONAL
# ==============================================================================

# Voltaje de configuracion del FPGA
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]


# Permitir relojes no relacionados
# (CPU 100 MHz vs UART 16 MHz del PLL)
set_clock_groups -asynchronous \
    -group [get_clocks sys_clk] \
    -group [get_clocks -of_objects [get_pins pll/clk_out2]]





# ==============================================================================
# CLOCK ROUTING
# ==============================================================================
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rst_btn_IBUF]


# ==============================================================================
# LEDs (16 LEDs onboard)
# ==============================================================================
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN V3  IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
set_property -dict { PACKAGE_PIN W3  IOSTANDARD LVCMOS33 } [get_ports {led[10]}]
set_property -dict { PACKAGE_PIN U3  IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports {led[13]}]
set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports {led[15]}]