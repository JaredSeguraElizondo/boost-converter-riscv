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

#### Notas de Diseño

- Canal ADC configurado en `daddr_o = 7'h16` (VAUX6, pines J3/K3 de la Basys 3).
- El XADC entrega el dato alineado a la izquierda en 16 bits; el módulo extrae los 12 MSB (`do_i[15:4]`).
- La bandera `new_data` puede limpiarse por software (RW1C en offset `0x0`) o automáticamente al leer el offset `0x4`.

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

