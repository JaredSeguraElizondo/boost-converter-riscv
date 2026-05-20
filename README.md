# Proyecto03

## Introducción

Este proyecto integra conceptos de organización de computadores, periféricos mapeados en memoria y visualización en VGA para implementar un sistema embebido de control de potencia.

La plataforma consiste en un sistema digital en FPGA con un procesador RISC-V de 32 bits (rv32i), memorias separadas para programa y datos, y periféricos específicos. La aplicación desarrolla el control en lazo cerrado de un convertidor DC-DC tipo boost, donde el procesador ejecuta el algoritmo de control y gestiona módulos de adquisición (ADC), actuadores (PWM), visualización (VGA) y comunicación (UART).

El convertidor boost se utiliza para elevar una tensión DC de entrada, siendo común en aplicaciones como sistemas con baterías, paneles fotovoltaicos y drivers LED. Debido a que variaciones en la carga o la fuente afectan la salida, el control con realimentación es esencial para garantizar estabilidad y buen desempeño.

Este proyecto replica el enfoque industrial de control embebido, pero diseñando desde cero un sistema basado en RISC-V y periféricos digitales, en lugar de usar un microcontrolador comercial.

# Investigación Previa

## 1. Arquitectura RISC-V RV32I y periféricos mapeados en memoria

RISC-V RV32I es un conjunto de instrucciones de 32 bits de tipo RISC (pocas instrucciones simples y rápidas). El procesador trabaja con registros de 32 bits y un bus de direcciones también de 32 bits, lo que le da acceso a un espacio de memoria de hasta 4 GB.

Los **periféricos mapeados en memoria** significa que los dispositivos externos (como un PWM, ADC, UART, etc.) no tienen instrucciones especiales para accederse; simplemente se les asigna una dirección de memoria fija. El procesador escribe o lee en esa dirección como si fuera RAM, y eso controla el periférico.

Ejemplo de mapa de memoria típico:

| Dirección base | Periférico |
|----------------|------------|
| `0x20000000`   | PWM        |
| `0x20000010`   | ADC (XADC) |
| `0x20000020`   | UART       |
| `0x20000030`   | VGA        |

---

## 2. Diseño de periféricos digitales de 32 bits con registros de control/estado/datos

Cada periférico se diseña con al menos tres tipos de registros internos de 32 bits:

- **Registro de control**: el procesador escribe aquí para configurar o activar el periférico.
- **Registro de estado**: el procesador lo lee para saber qué está pasando.
- **Registro de datos**: se usa para transferir el valor de interés.

Cada registro ocupa una dirección distinta dentro del espacio mapeado del periférico. El hardware decodifica la dirección y decide qué registro leer o escribir.

---

## 3. Principios de modulación PWM

PWM (Pulse Width Modulation) genera una señal digital que alterna entre alto y bajo a una frecuencia fija. Lo que varía es el **ciclo de trabajo** (*duty cycle*): el porcentaje del tiempo que la señal está en alto.

Relaciones clave:

- **Frecuencia**: qué tan rápido se repite el ciclo. `f = clk / periodo`
- **Resolución**: cuántos niveles distintos de duty cycle se pueden representar. Con N bits se tienen 2ᴺ niveles.
- **Ciclo de trabajo**: `duty = contador_comparador / periodo`

Existe un compromiso entre frecuencia y resolución: a mayor frecuencia con el mismo reloj base, el periodo tiene menos cuentas disponibles y la resolución disminuye.

---

## 4. Uso del XADC en FPGA Artix-7

El XADC es el conversor analógico-digital integrado en la Artix-7. Trabaja a 12 bits y puede medir señales externas o internas (temperatura, voltaje).

Flujo típico de operación:

1. **Iniciar conversión**: escribir en el registro de control del XADC para seleccionar el canal y disparar la conversión.
2. **Esperar dato disponible**: leer el registro de estado y verificar el bit de *End of Conversion* (EOC).
3. **Leer el dato**: una vez que EOC está activo, leer el registro de datos. El resultado está en los 12 bits más significativos del registro de 16 bits.

El acceso desde el procesador se hace a través de la interfaz DRP (Dynamic Reconfiguration Port), que también es mapeada en memoria.

---

## 5. Fundamentos de control del convertidor boost en lazo cerrado

Un convertidor boost eleva el voltaje de entrada. En lazo abierto el ciclo de trabajo es fijo; en **lazo cerrado** se ajusta automáticamente para mantener el voltaje de salida en un valor deseado (*setpoint*).

El lazo cerrado funciona así:

1. Se mide el voltaje de salida (con el XADC).
2. Se calcula el **error**: `e = Vref - Vmedido`
3. Un controlador (por ejemplo, PI) procesa el error y genera un nuevo ciclo de trabajo.
4. Ese duty cycle actualiza el PWM, que controla el switch del boost.

Esto se repite en cada ciclo de muestreo, corrigiendo perturbaciones en tiempo real.

---

## 6. Visualización VGA 640x480

VGA 640x480 a 60 Hz es uno de los estándares más simples de implementar en FPGA. El módulo VGA genera señales de sincronía horizontal (HSYNC) y vertical (VSYNC) junto con los datos de color RGB.

Para dibujar gráficas en tiempo real:

- Se mantiene un **buffer de muestras** (arreglo en memoria o registros) con los últimos N valores de voltaje/corriente.
- En cada barrido de pantalla, se recorre el buffer y se determina si el píxel actual pertenece a la curva.
- La gráfica se actualiza sample a sample conforme llegan nuevos datos del ADC.

Una estrategia simple es mapear el eje X a la posición horizontal del píxel y el eje Y al valor escalado de la muestra.

---

## 7. Comunicación UART 115200 8N1

UART es un protocolo serial asíncrono. La configuración **8N1** significa:

- 8 bits de datos
- Sin bit de paridad (N = None)
- 1 bit de stop

A 115200 baudios, cada bit dura aproximadamente 8.68 µs. El módulo UART transmite un byte a la vez: bit de start → 8 bits de datos a bit de stop.

Para enviar datos al PC, el procesador escribe el byte en el registro de datos del periférico UART. El módulo se encarga de serializar y transmitir. En el PC, un programa como Python o un terminal serie recibe los datos.

---

## 8. Modelado promedio y análisis dinámico del convertidor boost

El **modelo promediado** del convertidor boost describe su comportamiento dinámico ignorando el rizado de alta frecuencia. Se obtiene promediando las ecuaciones del circuito sobre un periodo de conmutación.

El modelo linealizado alrededor del punto de operación tiene la forma de una función de transferencia `G(s)` que relaciona el duty cycle con el voltaje de salida. Esta función presenta:

- Un **cero en el semiplano derecho** (fase no mínima), que complica el control.
- Un par de polos complejos que dependen de L, C y la carga.

Este modelo es la base para diseñar el controlador y predecir la estabilidad del sistema.

---

## 9. Diseño de controladores PI para convertidores DC-DC

Un controlador **PI** (Proporcional-Integral) corrige el error en estado estacionario (parte integral) y responde rápido a cambios (parte proporcional).

La función de transferencia es:

```
C(s) = Kp + Ki/s = Kp * (1 + 1/(Ti*s))
```

Para diseñarlo:

1. Se usa el modelo promediado del boost para conocer la planta `G(s)`.
2. Se elige el ancho de banda deseado del lazo cerrado.
3. Se ajustan `Kp` y `Ki` para tener margen de fase adecuado (típicamente > 45°).
4. Se verifica estabilidad con diagramas de Bode o lugar de raíces.

---

## 10. Discretización de controladores y efectos del muestreo

El controlador PI se diseña en tiempo continuo, pero se implementa en hardware digital, por lo que debe **discretizarse**.

Métodos comunes:

- **Euler hacia adelante**: `s ≈ (z-1)/T` — simple pero menos estable.
- **Euler hacia atrás**: `s ≈ (z-1)/(Tz)` — más estable.
- **Tustin (bilineal)**: `s ≈ 2(z-1)/(T(z+1))` — el más recomendado, preserva mejor la respuesta en frecuencia.

El **período de muestreo T** debe ser mucho menor que la constante de tiempo del sistema (regla general: al menos 10–20 veces más rápido que el ancho de banda del lazo). Un muestreo lento introduce retardo de fase adicional que puede desestabilizar el lazo.

---

## 11. Estrategias de validación experimental y comparación con modelos

Para validar el sistema implementado:

- **Respuesta al escalón**: aplicar un cambio brusco en el setpoint o en la carga y medir cómo responde el voltaje de salida. Se compara con la simulación del modelo.
- **Perturbaciones de carga**: variar la resistencia de carga y verificar que el controlador regule correctamente.
- **Métricas**: tiempo de establecimiento, sobrepico (*overshoot*), error en estado estacionario.
- **Comparación modelo vs. real**: graficar la respuesta simulada y la medida en el mismo eje (se puede usar la VGA o enviar datos por UART a Python para graficar con matplotlib).

Las discrepancias entre modelo y experimento suelen deberse a no linealidades, resistencias parásitas, retardo de muestreo o cuantización del ADC.

### 1. `uart_peripheral`

Periférico UART que actúa como puente entre el dominio de reloj del CPU y el dominio de reloj del UART. Incluye sincronización de señales entre dominios de reloj (CDC) mediante registros de sincronización de doble y triple flip-flop.

#### Puertos

| Puerto | Dirección | Ancho | Descripción |
|---|---|---|---|
| `clk_cpu_i` | entrada | 1 | Reloj del dominio CPU |
| `rst_cpu_i` | entrada | 1 | Reset del dominio CPU |
| `write_enable_i` | entrada | 1 | Habilitación de escritura MMIO |
| `addr_i` | entrada | 2 | Dirección del registro a acceder |
| `wdata_i` | entrada | 32 | Dato a escribir |
| `rdata_o` | salida | 32 | Dato leído |
| `clk_uart_i` | entrada | 1 | Reloj del dominio UART |
| `rst_uart_i` | entrada | 1 | Reset del dominio UART |
| `RsRx` | entrada | 1 | Línea de recepción serie |
| `RsTx` | salida | 1 | Línea de transmisión serie |

#### Mapa de Registros

| `addr_i` | Acceso | Bit | Descripción |
|---|---|---|---|
| `2'b00` | R/W | `[0]` | `reg_send` — Escribir `1` para iniciar transmisión |
| `2'b00` | R/W | `[1]` | `reg_new_rx` — Escribir `1` para limpiar la bandera de dato recibido |
| `2'b00` | R | `[2]` | `tx_busy` — `1` mientras hay una transmisión en curso |
| `2'b01` | R/W | `[7:0]` | `reg_data_tx` — Byte a transmitir |
| `2'b10` | R | `[7:0]` | `reg_data_rx` — Último byte recibido |

#### Notas de Diseño

- La señal `reg_send` se sincroniza al dominio UART con un registro de 2 etapas antes de conectarse a `tx_start`.
- `tx_rdy` y `rx_rdy` se sincronizan al dominio CPU con registros de 3 etapas para detectar flancos de subida (pulsos).
- Instancia internamente el módulo `UART` (núcleo serie externo).

---
## Simulación — `uart_peripheral`

El testbench valida el flujo completo de transmisión MMIO → UART en tres pruebas.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/imagenes/tb_uart.png" width="500">

### Test 1: enviar "Hi\n"

El CPU escribe los bytes `0x48` (H), `0x69` (i) y `0x0A` (salto de línea) uno a uno. El monitor confirma que `RsTx` recibe cada byte correctamente. Tiempo total: ~396 ns de simulación.

### Test 2: enviar "512\r\n"

Se transmiten los caracteres `0x35` (5), `0x31` (1), `0x32` (2), `0x0D` (CR) y `0x0A` (LF). Todos son recibidos en `RsTx` sin errores, verificando que el periférico maneja correctamente cadenas multi-byte con terminadores de línea.

### Test 3: lectura de registros

Se leen las tres direcciones del mapa de registros al finalizar la transmisión:

| `addr` | `rdata` | Interpretación |
|---|---|---|
| `00` | `0x00000000` | Estado: `tx_busy=0`, `new_rx=0`, `send=0` — periférico libre |
| `01` | `0x0000000A` | `data_tx = 0x0A` — último byte escrito en el registro de transmisión |
| `10` | `0x00000000` | `data_rx = 0x00` — no se recibió ningún byte en RsRx durante la prueba |

---

### 2. `gpio_peripheral`

Periférico de entrada digital que lee un botón físico, lo sincroniza al dominio del reloj y aplica un filtro de debounce de 20 ms para eliminar rebotes mecánicos.

#### Puertos

| Puerto | Dirección | Ancho | Descripción |
|---|---|---|---|
| `clk_i` | entrada | 1 | Reloj del sistema (100 MHz) |
| `rst_i` | entrada | 1 | Reset síncrono activo alto |
| `rdata_o` | salida | 32 | Dato de lectura MMIO (`[0]` = estado del botón) |
| `boton_i` | entrada | 1 | Señal del botón físico (sin sincronizar) |

#### Comportamiento

1. **Sincronizador CDC:** Doble flip-flop (`sync_boton`) para evitar metaestabilidad.
2. **Debounce:** Contador de 21 bits que espera `2,000,000` ciclos (20 ms a 100 MHz) de nivel estable antes de actualizar `boton_estable`.
3. **Salida:** `rdata_o = {31'd0, boton_estable}` — el bit 0 refleja el estado limpio del botón.

#### Parámetros

| Parámetro | Valor | Descripción |
|---|---|---|
| `DEBOUNCE_MAX` | `2_000_000` | Ciclos de reloj para el filtro de debounce (20 ms @ 100 MHz) |

---

### 3. `adc_xadc_mmio`

Periférico que encapsula el IP XADC de Xilinx mediante su puerto DRP (Dynamic Reconfiguration Port). Permite al procesador iniciar conversiones ADC, leer los resultados de 12 bits y configurar fuentes de disparo externas (señal externa o PWM).

#### Puertos

| Puerto | Dirección | Ancho | Descripción |
|---|---|---|---|
| `clk` | entrada | 1 | Reloj del sistema |
| `rst` | entrada | 1 | Reset síncrono activo alto |
| `we_i` | entrada | 1 | Habilitación de escritura MMIO |
| `addr_i` | entrada | 4 | Dirección del registro MMIO |
| `dat_i` | entrada | 32 | Dato a escribir |
| `dat_o` | salida | 32 | Dato leído |
| `pwm_trigger_i` | entrada | 1 | Disparo de conversión desde PWM |
| `adc_start_ext_i` | entrada | 1 | Disparo de conversión externo |
| `convst_o` | salida | 1 | Señal de inicio de conversión al XADC |
| `eoc_i` | entrada | 1 | End-of-Conversion del XADC |
| `drdy_i` | entrada | 1 | Data Ready del puerto DRP |
| `do_i` | entrada | 16 | Dato de salida del DRP |
| `daddr_o` | salida | 7 | Dirección del registro DRP |
| `den_o` | salida | 1 | Enable de lectura DRP |
| `dwe_o` | salida | 1 | Write Enable DRP (siempre `0`, solo lectura) |
| `di_o` | salida | 16 | Dato de entrada DRP (no usado) |



## 4. risc_v_cpu

Núcleo del procesador RV32I de 32 bits. Implementa el subconjunto del proyecto (`lw`, `sw`, instrucciones aritméticas y lógicas con inmediato y registro, shifts, branches, `jal` y `jalr`) bajo una arquitectura Harvard con buses externos independientes para programa y datos. Internamente se organiza en cinco etapas: Fetch, Decode, Execute, Memory y Writeback.

### Puertos

| Puerto | Dirección | Ancho | Descripción |
|---|---|---|---|
| `clk_i` | entrada | 1 | Reloj del sistema (100 MHz) |
| `reset_i` | entrada | 1 | Reset síncrono activo alto |
| `ProgAddress_o` | salida | 32 | Dirección de la siguiente instrucción |
| `ProgIn_i` | entrada | 32 | Instrucción leída desde la ROM |
| `DataAddress_o` | salida | 32 | Dirección del bus de datos |
| `DataOut_o` | salida | 32 | Dato a escribir en RAM o periférico |
| `DataIn_i` | entrada | 32 | Dato leído desde RAM o periférico |
| `we_o` | salida | 1 | Habilitación de escritura del bus de datos |

### Notas de Diseño

- El CPU expone los buses Harvard al exterior, lo que permite conectar ROM, RAM y periféricos mediante el decodificador central.
- El reset reinicia el PC a `0x0000_0000`, donde inicia la ejecución del programa.
- Los submódulos internos (PC, instruction decoder, ALU, banco de registros, sign extender y unidad de control) se documentan en detalle en `/doc`.

#### Mapa de Registros

| `addr_i` | Acceso | Bits | Descripción |
|---|---|---|---|
| `4'h0` | R/W | `[0]` | `start_pulse` — Escribir `1` para lanzar una conversión (pulso de 1 ciclo) |
| `4'h0` | R/W | `[1]` | `new_data` — Dato disponible; escribir `1` para limpiar (RW1C) |
| `4'h0` | R/W | `[2]` | `ext_start_en` — Habilitar disparo por `adc_start_ext_i` |
| `4'h0` | R | `[3]` | `busy` — `1` mientras hay una conversión en progreso |
| `4'h0` | R/W | `[4]` | `pwm_trig_en` — Habilitar disparo por `pwm_trigger_i` |
| `4'h4` | R | `[11:0]` | Resultado ADC de 12 bits (se limpia `new_data` automáticamente al leer) |

#### Máquina de Estados (FSM)

La FSM tiene tres estados: `IDLE` → `READ_DRP` → `WAIT_DRDY` → `IDLE`. Espera el pulso `eoc_i` para iniciar la lectura DRP, habilita `den_o` por un ciclo y aguarda `drdy_i` para capturar el resultado.

## 6. data_memory

Memoria RAM de 1024 palabras de 32 bits para almacenamiento de datos del programa. Implementa lectura combinacional y escritura síncrona habilitada por `WE`. El reset síncrono inicializa las 1024 posiciones en cero y tiene prioridad sobre la escritura.

### Puertos

| Puerto | Dirección | Ancho | Descripción |
|---|---|---|---|
| `clk` | entrada | 1 | Reloj del sistema (100 MHz) |
| `reset` | entrada | 1 | Reset síncrono activo alto |
| `WE` | entrada | 1 | Write enable |
| `A` | entrada | 32 | Dirección de la palabra |
| `WD` | entrada | 32 | Dato a escribir |
| `RD` | salida | 32 | Dato leído (combinacional) |

### Tabla de comportamiento

| reset | WE | Acción |
|---|---|---|
| 1 | X | `mem[todos] <= 0` |
| 0 | 1 | `mem[A[11:2]] <= WD` |
| 0 | 0 | Sin cambio |

## 7. pwm_peripheral

Periférico generador de PWM mapeado en memoria. Expone dos registros de 32 bits accesibles desde el CPU: uno de control/estado y otro de ciclo de trabajo. Produce además una señal de sincronización `pwm_trigger_o` al inicio de cada periodo, utilizada por el ADC para alinear las conversiones con la conmutación del convertidor.

### Puertos

| Puerto | Dirección | Ancho | Descripción |
|---|---|---|---|
| `clk_i` | entrada | 1 | Reloj del sistema (100 MHz) |
| `rst_i` | entrada | 1 | Reset síncrono activo alto |
| `addr_i` | entrada | 4 | Offset del registro a acceder |
| `wdata_i` | entrada | 32 | Dato a escribir desde el CPU |
| `we_i` | entrada | 1 | Habilitación de escritura MMIO |
| `cs_i` | entrada | 1 | Chip select desde el address decoder |
| `rdata_o` | salida | 32 | Dato leído por el CPU |
| `pwm_out_o` | salida | 1 | Señal PWM hacia el gate driver |
| `pwm_trigger_o` | salida | 1 | Pulso de sincronización al ADC |

### Mapa de Registros

| Offset | Bits | Acceso | Descripción |
|---|---|---|---|
| `0x00` | [0] | R/W | `enable`: habilita la generación PWM |
| `0x00` | [2:1] | R/W | `freq_sel`: selección de frecuencia (3 valores válidos) |
| `0x00` | [3] | R | `running`: refleja que el generador está activo |
| `0x04` | [6:0] | R/W | `duty_pct`: ciclo de trabajo en porcentaje (0 a 100) |

### Frecuencias configurables

Para un reloj base de 100 MHz se eligieron tres frecuencias por encima del umbral audible:

| `freq_sel` | Frecuencia | PERIOD (cuentas) |
|---|---|---|
| `2'b00` | 25 kHz | 4000 |
| `2'b01` | 50 kHz | 2000 |
| `2'b10` | 100 kHz | 1000 |

### Notas de Diseño

- El contador interno cuenta de 0 hasta `PERIOD-1` y vuelve a 0. Si `enable=0` el contador se congela.
- La salida es alta mientras `cnt < threshold`, donde `threshold = (duty_pct * PERIOD) / 100`.
- El trigger se genera combinacionalmente como `(cnt == 0) AND enable`, garantizando un pulso de exactamente un ciclo de reloj al inicio de cada periodo.
- Cualquier escritura de `duty_pct` mayor a 100 se satura al valor 100.

### Simulación — pwm_peripheral

El testbench valida dos comportamientos críticos del periférico: el cambio de frecuencia con ciclo de trabajo fijo y la variación del ciclo de trabajo a frecuencia constante.

**Test 1: cambio de frecuencia (ciclo de trabajo fijo en 50%)**

![Cambio de frecuencia PWM](https://gitlab.com/grupo034420017/proyecto03/-/raw/main/Imagenes_TestBenches/tb_PWM1.png?ref_type=heads)

Con `duty_pct = 50` se recorren los tres valores válidos de `freq_sel`: 0 (25 kHz, periodo de 40 µs), 1 (50 kHz, periodo de 20 µs) y 2 (100 kHz, periodo de 10 µs). La señal `pwm_out` cambia su periodo entre cada región sin perder la simetría del 50% de ciclo de trabajo, lo que confirma que el contador se reinicia correctamente al cambiar el valor de `PERIOD` y que el cálculo del umbral se reescala al nuevo periodo en cada cambio.

**Test 2: variación del ciclo de trabajo (frecuencia fija en 50 kHz)**

![Variación de duty cycle PWM](https://gitlab.com/grupo034420017/proyecto03/-/raw/main/Imagenes_TestBenches/tb_PWM2.png?ref_type=heads)

Se mantiene `freq_sel = 2'b01` (50 kHz) y se incrementa `duty_pct` en pasos de 5%: 45, 50, 55, 60. La señal `pwm_out` muestra cómo el ancho del pulso alto crece proporcionalmente mientras el periodo permanece constante en 20 µs. Los pulsos de `pwm_trig` aparecen una sola vez al inicio de cada periodo, confirmando la sincronización de un ciclo. Esto verifica el cálculo correcto del umbral `threshold = (duty_pct * PERIOD) / 100`.

### Simulación — Microcontrolador completo

El testbench integra el CPU con la ROM, la RAM y un modelo simplificado de los periféricos (mocks). El programa cargado en la ROM corresponde al lazo de control del convertidor: inicializa los periféricos, lee el ADC, calcula la actualización del ciclo de trabajo y la escribe en el PWM, y refresca el dato en el VGA. Los mocks devuelven valores fijos para que el CPU pueda recorrer el programa completo sin requerir hardware real:

- ADC: `new_data = 1` siempre, valor de conversión `0x800` (2048).
- GPIO: botón siempre presionado.
- UART: `tx_busy = 0` siempre.

![Forma de onda del CPU integrado](https://gitlab.com/grupo034420017/proyecto03/-/raw/main/Imagenes_TestBenches/tb_CPU.jpeg)

Tras liberar el reset, `ProgAddress` se incrementa en 4 cada ciclo, confirmando el avance secuencial correcto del PC. Las primeras instrucciones (PC `0x00` a `0x44`) cargan constantes en los registros y no generan escrituras en el bus (`we_cpu = 0`), lo que se observa en `rdata_ram` y `rdata_periph` estables en cero. La primera activación de `we_cpu` ocurre alrededor de los 220 ns, correspondiente a la primera escritura sobre un periférico.

El monitor del testbench filtra las escrituras a periféricos y produce la siguiente traza ordenada por PC:

| PC | Acción | Significado |
|---|---|---|
| `0x4c` | `PWM_CTRL <= 0x01` | Habilita la generación PWM |
| `0x54` | `PWM_DUTY <= 50%` | Ciclo de trabajo inicial |
| `0x58` | `ADC_CTRL <= 0x00` | Configuración del ADC |
| `0x60` | `VGA_CTRL <= 0x01` | Habilita visualización VGA |
| `0x68` | `ADC_CTRL <= 0x01` | Dispara primera conversión |
| `0x74` | lectura `ADC_DATA = 0x800` | Captura del valor convertido (mock) |
| `0x114` | `PWM_DUTY <= 51%` | Actualización del duty por el controlador integral |
| `0x134` | `VGA_DATA <= 236` | Envío de la muestra escalada al VGA |

**pwm_peripheral — Base: PWM_BASE**

| Offset | Campo | R/W | Descripción |
|---|---|---|---|
| +0x0 [0] | enable | R/W | Habilita la generación PWM |
| +0x0 [2:1] | freq_sel | R/W | Selección de frecuencia (3 valores válidos) |
| +0x0 [3] | running | R | Generador activo |
| +0x4 [6:0] | duty_pct | R/W | Ciclo de trabajo (0 a 100, saturado) |


---

## Mapa de Registros

### `uart_peripheral` — Base: `UART_BASE`

| Offset | Campo | R/W | Descripción |
|---|---|---|---|
| `+0x0` | `[2]` tx_busy | R | Transmisión en curso |
| `+0x0` | `[1]` new_rx | R/W | Nuevo dato recibido (escribir `1` para limpiar) |
| `+0x0` | `[0]` send | W | Iniciar transmisión |
| `+0x4` | `[7:0]` data_tx | R/W | Byte a transmitir |
| `+0x8` | `[7:0]` data_rx | R | Byte recibido |

### `gpio_peripheral` — Base: `GPIO_BASE`

| Offset | Campo | R/W | Descripción |
|---|---|---|---|
| `+0x0` | `[0]` button | R | Estado del botón (con debounce) |

### `adc_xadc_mmio` — Base: `ADC_BASE`

| Offset | Campo | R/W | Descripción |
|---|---|---|---|
| `+0x0` | `[4]` pwm_trig_en | R/W | Habilitar disparo por PWM |
| `+0x0` | `[3]` busy | R | Conversión en curso |
| `+0x0` | `[2]` ext_start_en | R/W | Habilitar disparo externo |
| `+0x0` | `[1]` new_data | R/W | Dato listo (RW1C) |
| `+0x0` | `[0]` start | W | Iniciar conversión (pulso) |
| `+0x4` | `[11:0]` adc_data | R | Resultado de la conversión ADC |

---

## Arquitectura e Integración

Cada periférico recibe las señales de bus `write_enable`, `addr` y `wdata/rdata` desde el decodificador central. El arbitraje de direcciones y la selección del periférico activo se resuelven en el módulo TOP del proyecto.

---

# Resultados y Análisis de Simulación: Periférico VGA

## Banco de pruebas

Se desarrollaron dos testbenches con objetivos complementarios.

**Testbench 1 (`tb_vga_periph.sv`):** Banco autoverificable con 8 pruebas (T1–T8) que cubren reset, registro de control, temporización de HSYNC y VSYNC, blanking y detección de píxel verde. Opera a 25 MHz y acumula resultados en contadores `pass_count` / `fail_count`.

**Testbench 2 (`tb_vga_visual.sv`):** Banco de diagnóstico visual desarrollado ante la ausencia de señal verde en las primeras ejecuciones del TB1. En lugar de detectar cualquier píxel verde en un frame completo, llena todo el buffer circular con el mismo valor ADC (`adc = 2048` → fila 239) y verifica el ancho exacto de la línea verde en ciclos, su posición temporal precisa y las condiciones de color antes y después de ella.

---

## Resultados

### Testbench 1 — Log de simulación

```
========================================
 Inicio de simulación
========================================

[T1] Estado de reset
  PASS [HSYNC=1 en reset]
  PASS [VSYNC=1 en reset]
  PASS [RED=0  en reset]
  PASS [GRN=0  en reset]
  PASS [BLU=0  en reset]

[T2] Registro de control
  PASS [rdata[0]=1 tras habilitar]
  PASS [rdata[0]=0 tras deshabilitar]

[T3] Periodo de HSYNC
  INFO [HSYNC] periodo medido = 32000 ns
  PASS [HSYNC periodo correcto]

[T4] Ancho de pulso HSYNC
  INFO [HSYNC] ancho de pulso = 3840 ns
  PASS [HSYNC ancho de pulso correcto]

[T5] Periodo de VSYNC (esperar ~2 frames...)
  INFO [VSYNC] periodo medido = 16800000 ns
  PASS [VSYNC periodo correcto]

[T6] RGB = 0 durante blanking horizontal
  PASS [RED=0 durante H-blanking]
  PASS [GRN=0 durante H-blanking]
  PASS [BLU=0 durante H-blanking]

[T7] Deteccion de pixel verde tras escritura de muestra
  PASS [Pixel verde detectado en frame tras escritura]

[T8] Deshabilitar VGA apaga salidas
  PASS [HSYNC=1 tras deshabilitar]
  PASS [VSYNC=1 tras deshabilitar]
  PASS [RED=0  tras deshabilitar]
  PASS [GRN=0  tras deshabilitar]
  PASS [BLU=0  tras deshabilitar]

========================================
 Resultados: 19 PASS  |  0 FAIL
 TODOS LOS TESTS PASARON
========================================
```

### Testbench 1 — Tabla resumen

| ID | Descripción | Valor esperado | Medido / Observado | Estado |
|---|---|---|---|---|
| T1 | HSYNC, VSYNC y RGB en reset | `1`, `1`, `000` | `1`, `1`, `000` | **PASS** |
| T2 | Lectura de `ctrl_enable` tras escritura | `rdata[0] = 1` / `0` | `1` / `0` | **PASS** |
| T3 | Período de HSYNC | 32 000 ns | 32 000 ns | **PASS** |
| T4 | Ancho de pulso HSYNC | 3 840 ns | 3 840 ns | **PASS** |
| T5 | Período de VSYNC | 16 800 000 ns | 16 800 000 ns | **PASS** |
| T6 | RGB = 0 durante H-blanking | `000` | `000` | **PASS** |
| T7 | Píxel verde con `adc = 0` (fila 479) | `GRN=F, RED=0, BLU=0` | Detectado | **PASS** |
| T8 | Syncs y RGB al deshabilitar | HSYNC=1, VSYNC=1, RGB=000 | Correcto | **PASS** |
| — | **Total** | **19 afirmaciones** | — | **19 PASS / 0 FAIL** |

### Testbench 1 — Forma de onda 

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/Imagenes_TestBenches/VGA_TB1.png" width="430">

La Figura 1 muestra la captura de la simulación, correspondiente a las pruebas T2 y T3. Los aspectos más relevantes son:

- `wdata` transiciona de `00000000` a `00000001` alrededor de los 6 950 µs, correspondiente a la escritura `enable = 1` de la prueba T2. Inmediatamente, `rdata` refleja `00000001`, confirmando que el registro de control se actualiza y es legible en el ciclo siguiente.
- `hsync` exhibe pulsos activos-bajos periódicos cuyo período es consistente con el valor medido en T3 (32 000 ns = 800 ciclos × 40 ns).
- `vsync = 1` sostenido en toda la ventana mostrada, lo cual es correcto dado que el período de VSYNC es de 16.8 ms y su pulso (≈ 64 µs de duración) no cae dentro del intervalo de 300 µs capturado.
- `blu[3:0]` alterna entre `2` (fondo azul oscuro, zona visible) y `0` (blanking) en correspondencia con los ciclos de HSYNC, confirmando el comportamiento de la capa de fondo del módulo `vga_render`.
- `red = 0` y `grn = 0` de forma sostenida, coherente con que la muestra escrita aún no ha sido alcanzada por el barrido en esa región temporal.
- `pass_count = 9` y `fail_count = 0` al momento de la captura, indicando que las primeras nueve afirmaciones (T1 completo, T2 y T3) ya fueron evaluadas y aprobadas.

---

### Testbench 2 — Log de simulación

```
============================================
 TB VISUAL: vga_periph
============================================
 Patron esperado:
   blu[3:0] alterna entre 2 y 0 (fondo/blanking)
   grn[3:0] sube a F por 25,600 ns en la fila 239
   red[3:0] siempre en 0
============================================
[1] VGA habilitado
[2] Escribiendo 640 muestras (adc=2048 → fila 239)...
    Buffer lleno. grn=F aparecera en fila 239 por 25,600 ns.
[3] Esperando negedge vsync...
    negedge vsync en t = 15680140 ns

  >>> Zoom aqui en el waveform viewer:
  >>> grn=F (verde) desde t = 24448140 ns
  >>> grn=F (verde) hasta t = 24473740 ns
  >>> Duracion visible      = 25,600 ns
  >>> Escala recomendada    = 5 us/div

[4] Verificacion: grn=0 justo antes de la fila verde
  PASS [grn=0 antes de la linea verde]
  PASS [blu=0 en blanking horizontal previo]
[5] Verificacion: grn=F durante la linea verde
    Ciclos con grn=F detectados: 640 de 640 esperados
  PASS [grn=F durante la linea verde (>= 630 ciclos)]
[6] Verificacion: grn=0 despues de la linea verde
  PASS [grn=0 despues de la linea verde]
============================================
 Resultados: 4 PASS  |  0 FAIL
 TODOS LOS TESTS PASARON
============================================
```

### Testbench 2 — Tabla resumen

| ID | Descripción | Valor esperado | Medido / Observado | Estado |
|---|---|---|---|---|
| [4] | `grn = 0` justo antes de la fila 239 | `0` | `0` | **PASS** |
| [4] | `blu = 0` en blanking horizontal previo | `0` | `0` | **PASS** |
| [5] | Ciclos con `grn = F` durante la línea verde | 640 ciclos (≥ 630) | 640 ciclos | **PASS** |
| [6] | `grn = 0` después de la fila verde | `0` | `0` | **PASS** |
| — | **Total** | **4 afirmaciones** | — | **4 PASS / 0 FAIL** |

El testbench también reportó las marcas de tiempo exactas de la línea verde: inicio en t = 24 448 140 ns y fin en t = 24 473 740 ns, con una duración de 25 600 ns = 640 ciclos × 40 ns, exactamente igual al ancho visible horizontal del estándar.

### Testbench 2 — Forma de onda 

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/Imagenes_TestBenches/VGA_TB2.png" width="430">

La igura muestra la captura del simulador alrededor de t = 74 865 µs, durante la verificación [5] del TB2. Los aspectos más relevantes son:

- `grn[3:0]` presenta un pulso de valor `F` (verde brillante) claramente visible en el centro de la captura, flanqueado por períodos en `0`. Este pulso corresponde al barrido de la fila 239, la fila donde `vga_render` detecta la coincidencia `vcount == sample_y` para todos los 640 slots del buffer circular. Su ancho en la forma de onda es consistente con los 25 600 ns reportados en el log.
- `blu[3:0]` alterna entre `2` y `0` a ambos lados del pulso verde, confirmando que las regiones de fondo y blanking adyacentes se generan correctamente. Durante el pulso verde, `blu` se mantiene en `0` dado que la capa de plot tiene mayor prioridad que la capa de fondo.
- `red[3:0] = 0` de forma sostenida en todo el intervalo, confirmando que el canal rojo no interfiere con ninguna de las capas activas.
- `offset = 4` y `wdata = 00000800` (valor estable), indicando que el testbench ya completó las 640 escrituras del buffer y se encuentra en la fase de monitoreo pasivo.
- `pass_count = 4` y `fail_count = 0` al final de la simulación.
- `hsync` continúa generando pulsos correctos, y `vsync = 1` sostenido, coherente con que la captura se toma dentro del área visible del frame (fila 239, lejos del blanking vertical).

---

## Análisis e interpretación


### Estado de reset y registro de control (T1, T2, T8)

Al liberar el reset, HSYNC y VSYNC permanecen inactivos y RGB en cero porque `ctrl_enable` se inicializa en `0` y las salidas se fuerzan combinacionalmente desde `vga_periph` mientras `enable = 0`. La prueba T2 confirmó que las escrituras al registro de control son funcionales y que el dato de retorno es inmediatamente consistente. La prueba T8 verificó el comportamiento simétrico al deshabilitar.

### Blanking (T6)

El resultado RGB = `000` durante el blanking horizontal confirma que `video_on` se genera correctamente y que `vga_render` lo prioriza sobre las demás capas. Este comportamiento también es visible en ambas formas de onda mediante la alternancia de `blu` entre `2` y `0`.

### Generación del píxel de plot y diagnóstico de la falla inicial (T7 y TB2)

Esta fue la prueba más relevante del proceso de verificación y la razón del segundo testbench.

En la versión original del TB1, la ventana de monitoreo de T7 abarcaba solo `V_VISIBLE × H_TOTAL = 384 000` ciclos desde el flanco de bajada de VSYNC. El problema es que ese flanco ocurre en `vcount = 490`, no en `vcount = 0`: la región visible del frame siguiente no comienza hasta que el contador vertical recorra las 35 líneas de blanking restantes. El píxel verde de la fila 479 aparece aproximadamente en el ciclo `(35 + 479) × 800 ≈ 411 200` desde ese flanco, fuera de la ventana de 384 000 ciclos. La falla no era un defecto del hardware sino un error de cobertura temporal en el banco de pruebas.

La corrección amplió la ventana a `V_TOTAL × H_TOTAL = 420 000` ciclos, cubriendo el frame completo. Con esto, T7 pasó en el TB1.

El TB2 confirmó de forma independiente y más rigurosa que el hardware es correcto: los 640 ciclos con `grn = F` detectados coinciden exactamente con los 640 esperados (ancho visible de 25 600 ns). Las verificaciones antes y después de la línea verde confirman que no hay contaminación de color en las filas adyacentes. También puso en evidencia la latencia de un ciclo del pipeline registrado de `vga_render`, contemplada en el margen de entrada del banco (`repeat(6)` antes de la ventana de conteo).

### Limitaciones

El periférico no fue validado sobre hardware real en el proyecto.