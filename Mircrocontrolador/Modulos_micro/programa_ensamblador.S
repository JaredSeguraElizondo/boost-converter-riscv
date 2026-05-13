#Programa 1
    addi x1, x0, 5        # x1 = 5
    addi x2, x0, 3        # x2 = 3
    add  x3, x1, x2       # x3 = x1 + x2 = 8
    sub  x4, x3, x2       # x4 = x3 - x2 = 5

    sw   x3, 0(x0)        # Mem[0] = x3
    lw   x5, 0(x0)        # x5 = Mem[0]

loop:
    addi x1, x1, -1       # x1--
    beq  x1, x0, end      # if x1 == 0 → salir
    jal  x0, loop         # saltar a loop (sin guardar RA)

end:
    jal  x0, end          # bucle infinito (halt)