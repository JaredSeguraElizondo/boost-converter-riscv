# ==============================================================================
# Proy03_softstart.s
# Proyecto 3 — Control con SOFT START
# ==============================================================================
#
# Estrategia:
#   1. Al arrancar, fijar PWM_DUTY = 50% sin lazo cerrado
#   2. Esperar a que Vout llegue a 14V (el boost se carga gradualmente)
#   3. Recien ahi entrar al lazo de control PI para llegar a 24V
#
# Beneficio: evita el pico de corriente del arranque desde 0V y el
# escenario donde el controlador queda atascado en duty=min.
#
# Threshold soft start: 14V → 0.525V XADC → 2150 cuentas
# Vref control:         24V → 0.9V XADC → 3686 cuentas
#
# Controlador PI:  u[k] = u[k-1] + 0.006·e[k] - 0.003·e[k-1]
#                  En Q10: b0=6, b1=-3
# Duty limits: [20%, 80%]
# ==============================================================================

_start:
    lui   x20, 0x10
    lui   x15, 0x2

    addi  x9,  x0, 80           # DUTY_MAX
    addi  x11, x0, 20           # DUTY_MIN
    addi  x13, x0, 512          # MAX_SAMPLES

    lui   x10, 0x14             # ACC_MAX = 80<<10 = 81920

    # Vref = 3686
    lui   x1, 1
    addi  x1, x1, -410

    # Inicializar estado
    add   x2, x0, x0
    add   x3, x0, x0
    add   x4, x0, x0
    add   x6, x0, x0
    add   x12, x0, x0
    add   x14, x15, x0

    # PWM: enable, 50 kHz
    addi  x5, x0, 3
    sw    x5, 0x100(x20)

    # *** SOFT START: PWM_DUTY = 50% fijo ***
    addi  x5, x0, 50
    sw    x5, 0x104(x20)

    # ADC: limpiar control
    sw    x0, 0x110(x20)

    # VGA: enable
    addi  x5, x0, 1
    sw    x5, 0x120(x20)


# ==============================================================================
# SOFT START — esperar a que Vout llegue a 14V
# ==============================================================================

soft_start:
    addi  x5, x0, 1
    sw    x5, 0x110(x20)          # disparar ADC

ss_poll:
    lw    x8, 0x110(x20)
    andi  x8, x8, 2
    beq   x8, x0, ss_poll

    lw    x7, 0x114(x20)          # leer ADC

    # Mostrar progreso en VGA durante soft start
    sw    x7, 0x128(x20)          # VGA_VOLT = adc
    addi  x5, x0, 50
    sw    x5, 0x12C(x20)          # VGA_PWM = 50

    # Comparar contra threshold (14V = 2150 cuentas)
    # 2150 no cabe en addi (max 2047), construir en dos pasos
    addi  x5, x0, 2047
    addi  x5, x5, 103             # x5 = 2150

    blt   x7, x5, soft_start      # si adc < 2150, seguir esperando

    # ── Llegamos a 14V → preparar entrada al lazo ──
    # u_acc inicial = 50<<10 = 51200 (para que duty arranque en 50)
    addi  x6, x0, 50
    slli  x4, x6, 10              # u_acc = 51200

    # e[n-1] = Vref - adc_actual (estado coherente al entrar)
    sub   x3, x1, x7


# ==============================================================================
# LAZO PRINCIPAL DE CONTROL
# ==============================================================================

main_loop:

    addi  x5, x0, 1
    sw    x5, 0x110(x20)

poll_adc:
    lw    x8, 0x110(x20)
    andi  x8, x8, 2
    beq   x8, x0, poll_adc

    lw    x7, 0x114(x20)

    # ── Controlador PI ──
    sub   x2, x1, x7              # e[n] = Vref - adc

    # 6·e[n]
    slli  x8,  x2, 2
    slli  x17, x2, 1
    add   x8,  x8, x17

    # 3·e[n-1]
    slli  x17, x3, 1
    add   x17, x17, x3

    # delta = 6·e[n] - 3·e[n-1]
    sub   x8, x8, x17

    # u_acc += delta
    add   x4, x4, x8

    # e[n-1] = e[n]
    add   x3, x2, x0

    # Anti-windup: u_acc clamp a [0, ACC_MAX]
    bge   x4, x0, aw_max
    add   x4, x0, x0
    jal   x0, aw_done
aw_max:
    blt   x4, x10, aw_done
    add   x4, x10, x0
aw_done:

    srai  x6, x4, 10              # duty = u_acc >> 10

    # Clamp duty a [DUTY_MIN, DUTY_MAX]
    bge   x6, x11, clamp_max
    add   x6, x11, x0
    jal   x0, write_outputs
clamp_max:
    blt   x6, x9, write_outputs
    add   x6, x9, x0

write_outputs:
    sw    x6, 0x104(x20)

    # VGA Y = 460 - ((adc * 7) >> 6)
    slli  x8,  x7, 2
    slli  x17, x7, 1
    add   x8,  x8, x17
    add   x8,  x8, x7
    srai  x8,  x8, 6
    addi  x17, x0, 460
    sub   x8,  x17, x8
    sw    x8,  0x124(x20)

    sw    x7, 0x128(x20)
    sw    x6, 0x12C(x20)

    bge   x12, x13, skip_store
    sw    x7, 0(x14)
    addi  x14, x14, 4
    addi  x12, x12, 1
skip_store:

    lw    x8, 0x130(x20)
    andi  x8, x8, 1
    bne   x8, x0, uart_export

    jal   x0, main_loop


# ==============================================================================
# UART EXPORT
# ==============================================================================

uart_export:
    add   x16, x15, x0
    add   x18, x12, x0
    beq   x18, x0, uart_done

uart_send_loop:
    beq   x18, x0, uart_done
    lw    x17, 0(x16)

    addi  x22, x0, 1

    addi  x21, x0, 1000
    add   x19, x0, x0
div_thous:
    blt   x17, x21, end_thous
    sub   x17, x17, x21
    addi  x19, x19, 1
    jal   x0, div_thous
end_thous:
    beq   x19, x0, do_hund
    add   x22, x0, x0
    addi  x19, x19, 0x30
    jal   x31, uart_send_char

do_hund:
    addi  x21, x0, 100
    add   x19, x0, x0
div_hund:
    blt   x17, x21, end_hund
    sub   x17, x17, x21
    addi  x19, x19, 1
    jal   x0, div_hund
end_hund:
    beq   x19, x0, maybe_h
    add   x22, x0, x0
    addi  x19, x19, 0x30
    jal   x31, uart_send_char
    jal   x0, do_tens
maybe_h:
    bne   x22, x0, do_tens
    addi  x19, x19, 0x30
    jal   x31, uart_send_char

do_tens:
    addi  x21, x0, 10
    add   x19, x0, x0
div_tens:
    blt   x17, x21, end_tens
    sub   x17, x17, x21
    addi  x19, x19, 1
    jal   x0, div_tens
end_tens:
    beq   x19, x0, maybe_t
    add   x22, x0, x0
    addi  x19, x19, 0x30
    jal   x31, uart_send_char
    jal   x0, do_ones
maybe_t:
    bne   x22, x0, do_ones
    addi  x19, x19, 0x30
    jal   x31, uart_send_char

do_ones:
    addi  x19, x17, 0x30
    jal   x31, uart_send_char

    addi  x19, x0, 0x0A
    jal   x31, uart_send_char

    addi  x16, x16, 4
    addi  x18, x18, -1
    jal   x0, uart_send_loop

uart_done:
    add   x12, x0, x0
    add   x14, x15, x0
    jal   x0, main_loop


uart_send_char:
    sw    x19, 0x044(x20)
    addi  x8, x0, 1
    sw    x8, 0x040(x20)
wait_tx:
    lw    x8, 0x040(x20)
    andi  x8, x8, 4
    bne   x8, x0, wait_tx
    jalr  x0, x31, 0