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


# Descripción de Módulos 

---


## Módulo: UART (`uart_core_inst`)
**Objetivo:**  
Núcleo UART encargado de la serialización y deserialización de datos para transmisión y recepción serial.

**Entradas:**  
- `clk`  
- `reset`  
- `tx_start`  
- `data_in[7:0]`  
- `rx`

**Salidas:**  
- `tx_rdy`  
- `rx_data_rdy`  
- `data_out[7:0]`  
- `tx`

**Relación:**  
Es instanciado por `uart_peripheral`.  
Recibe datos y señal de inicio desde la lógica de sincronización y entrega datos recibidos junto con señales de estado.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/Uart01.png?ref_type=heads" width="500">


**Funcionamiento:**  
Es un IP externo instanciado como caja negra. Internamente incluye:
- Transmisor: serializa `data_in` cuando `tx_start` se activa.
- Receptor: muestrea `rx`, detecta el bit de inicio, captura 8 bits y activa `rx_data_rdy`.

Opera completamente en el dominio `clk_uart_i`.

**Diseño:**  
Se reutiliza el núcleo UART porque ya implementa el generador de baudrate y la máquina de estados serie.  
Interfaz estándar de 8 bits con flags de estado.

---
## _Sub-Módulos_
### Sincronizador `reg_send → tx_start_uart` (CPU → UART)

**Objetivo:**  
Cruzar la señal `reg_send` del dominio `clk_cpu_i` al dominio `clk_uart_i` evitando metaestabilidad.

**Entradas:**  
- `clk_uart_i`  
- `rst_uart_i`  
- `reg_send`

**Salidas:**  
- `tx_start_uart`

**Relación:**  
Conecta el registro de control escrito por la CPU con la entrada `tx_start` del núcleo UART.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/Uart02.png?ref_type=heads" width ="500">

**Funcionamiento:**  
Implementado con dos flip-flops D en serie en el dominio `clk_uart_i`:

- El primero absorbe posible metaestabilidad.
- El segundo entrega una señal estable.

`sync_send[1]` se asigna directamente a `tx_start_uart`.

**Diseño:**  
Patrón estándar de sincronizador de 2 FF.  
No requiere lógica combinacional adicional.  
Equivale a un retardo de 2 ciclos en el dominio UART.

---

## Sincronizador + Detector de Flanco `tx_rdy` (UART → CPU)

**Objetivo:**  
Sincronizar `tx_rdy_uart` al dominio CPU y generar un pulso de un ciclo ante flanco de subida.

**Entradas:**  
- `clk_cpu_i`  
- `rst_cpu_i`  
- `tx_rdy_uart`

**Salidas:**  
- `tx_rdy_pulse`

**Relación:**  
El pulso limpia automáticamente `reg_send` y `tx_busy`.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/Uart03.png?ref_type=heads" width ="500">

**Funcionamiento:**  
Tres flip-flops en el dominio `clk_cpu_i` sincronizan la señal.  
Si:

- `sync[1] = 1`
- `sync[2] = 0`

→ se detecta flanco de subida y se genera un pulso de exactamente un ciclo CPU.

### Tabla de verdad – Detector de flanco

| sync[1] | sync[2] | tx_rdy_pulse |
|----------|----------|--------------|
| 0 | 0 | 0 |
| 0 | 1 | 0 |
| 1 | 0 | 1 (flanco detectado) |
| 1 | 1 | 0 |

---

##  Sincronizador + Detector de Flanco `rx_rdy` (UART → CPU)

**Objetivo:**  
Generar `rx_rdy_pulse` para capturar el dato recibido.

**Entradas:**  
- `clk_cpu_i`  
- `rst_cpu_i`  
- `rx_rdy_uart`

**Salidas:**  
- `rx_rdy_pulse`

**Relación:**  
Dispara la captura de `data_out_uart` en `reg_data_rx` y activa `reg_new_rx`.

**Diseño:**  
Estructura idéntica al detector de `tx_rdy`:  
- 3 FF en dominio CPU  
- Lógica AND/NOT  
- Misma tabla de verdad

---

## Registros de Control / Estado (dominio CPU)

**Objetivo:**  
Banco de registros accesibles por el procesador.  
Almacena estado y datos TX/RX.

**Entradas:**  
- `clk_cpu_i`  
- `rst_cpu_i`  
- `write_enable_i`  
- `addr_i[1:0]`  
- `wdata_i[31:0]`  
- `tx_rdy_pulse`  
- `rx_rdy_pulse`  
- `data_out_uart[7:0]`

**Salidas:**  
- `reg_send`  
- `reg_new_rx`  
- `reg_data_tx[7:0]`  
- `reg_data_rx[7:0]`  
- `tx_busy`

**Relación:**  
Es el núcleo de control del periférico.  
Interconecta CPU ↔ UART mediante sincronizadores.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/UART05.png?ref_type=heads" width ="500">

### Funcionamiento

Decodificación mediante `case(addr_i)`:

- `00` → Control y estado
- `01` → Dato TX

Eventos automáticos:
- `tx_rdy_pulse` → limpia `reg_send` y `tx_busy`
- `rx_rdy_pulse` → captura `data_out_uart` y activa `reg_new_rx`

### Tabla de decodificación de escritura

| addr_i | Acción |
|--------|--------|
| 00 | `wdata[0]=1` → activa TX (`reg_send=1`, `tx_busy=1`) <br> `wdata[1]=1` → limpia `reg_new_rx` |
| 01 | Carga `reg_data_tx` con `wdata[7:0]` |
| 10 | Sin efecto |
| 11 | Sin efecto |

---

## Bus de Lectura (lógica combinacional `rdata_o`)

**Objetivo:**  
Exponer el estado interno al procesador durante lecturas.

**Entradas:**  
- `addr_i[1:0]`  
- `tx_busy`  
- `reg_new_rx`  
- `reg_send`  
- `reg_data_tx[7:0]`  
- `reg_data_rx[7:0]`

**Salidas:**  
- `rdata_o[31:0]`

**Relación:**  
Canal de retorno hacia la CPU.  
No tiene estado propio.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/Uart06.png?ref_type=heads" width ="500">

**Funcionamiento:**  
Lógica puramente combinacional (`always_comb`).  
Un `case(addr_i)` selecciona el contenido de `rdata_o`.

Los bits superiores del bus de 32 bits se rellenan con ceros.

### Mapa de registros

| addr_i | rdata_o[31:0] | Descripción |
|--------|--------------|-------------|
| 00 | `{29'b0, tx_busy, reg_new_rx, reg_send}` | Registro de estado |
| 01 | `{24'b0, reg_data_tx}` | Dato TX |
| 10 | `{24'b0, reg_data_rx}` | Dato RX |
| 11 | `32'h0` | Sin uso |

---

# Memoria de Datos

---

##  RAM: Arreglo de Memoria (`mem`)

**Nombre:**  
`mem` — Arreglo de palabras de 32 bits

**Objetivo:**  
Almacenar los datos del sistema.  
Consta de 1024 posiciones de 32 bits cada una → total de **4 KB de RAM de datos**.

**Entradas:**  
- Señales de escritura provenientes de la lógica síncrona:
  - `WD[31:0]`
  - Dirección decodificada `A[11:2]`
  - `WE`

**Salidas:**  
- `RD[31:0]` (dato leído hacia la lógica combinacional)

**Relación con otros módulos:**  
Es el recurso compartido entre:
- Lógica de escritura (síncrona)
- Lógica de lectura (asíncrona)

Ambas acceden en paralelo mediante `A[11:2]`.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/RAM1.png?ref_type=heads" width="440">


### Funcionamiento

Se declara como:
`logic [31:0] mem [0:1023];`


- Se indexa con `A[11:2]` (10 bits)
- `2¹⁰ = 1024` posiciones
- `A[1:0]` se descartan (alineación a palabra de 4 bytes)
- `A[31:12]` se ignoran (la decodificación externa decide si la dirección pertenece a la RAM)

En reset, todas las posiciones se inicializan en cero.

### Diseño y Justificación

- La FPGA infiere este arreglo como **BRAM o distributed RAM**.
- Uso de `A[11:2]`:
  - 10 bits → 1024 palabras
- Alineación a word (32 bits)
- Decodificación de región de memoria ocurre fuera del módulo.

---

## _Sub-Módulos_
###  Módulo: Lógica de Escritura Síncrona (`always_ff`)

**Nombre:**  
Escritura síncrona con reset

**Objetivo:**  
- Escribir datos de 32 bits en memoria.
- Inicializar toda la memoria en cero durante reset.

**Entradas:**  
- `clk`
- `reset`
- `WE`
- `A[11:2]`
- `WD[31:0]`

**Salidas:**  
- Actualización de `mem[A[11:2]]`

**Relación:**  
Recibe señales del bus del procesador:
- `WE` ← `we_ram_o`
- `A`, `WD` ← pipeline

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/RAM2.png?ref_type=heads" width="400">

### Funcionamiento

En cada flanco positivo del reloj:

1. Si `reset = 1`  
   → Un bucle `for` inicializa las 1024 posiciones en cero  
   (la síntesis lo convierte en lógica paralela).

2. Si `reset = 0` y `WE = 1`  
   → `mem[A[11:2]] ← WD`

3. Si `WE = 0`  
   → No hay cambio (los registros mantienen su valor)

### Tabla de verdad – Escritura

| reset | WE | Acción |
|--------|----|--------|
| 1 | X | `mem[todos] ← 0` |
| 0 | 1 | `mem[A[11:2]] ← WD` |
| 0 | 0 | Sin cambio |

### Diseño

La prioridad:
`if (reset)`
`else if (WE)`
es intencional:  
el reset siempre tiene prioridad sobre escritura.

El sintetizador infiere:
- Flip-flop por cada bit
- `WE` como clock enable
- Reset síncrono

---

##  Módulo: Lógica de Lectura Asíncrona

**Nombre:**  
Lectura combinacional

**Objetivo:**  
Exponer inmediatamente el contenido de la posición apuntada por `A`.

**Entradas:**  
- `A[11:2]`
- `mem[A[11:2]]`

**Salidas:**  
- `RD[31:0]`

**Relación:**  
Conecta directamente la memoria con el bus de lectura del procesador.  
El resultado alimenta el `read_mux` del pipeline.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/RAM3.png?ref_type=heads" width="550">

### Funcionamiento

Implementado con: `assign RD = mem[A[11:2]];`

- Camino puramente combinacional.
- No hay flip-flops intermedios.
- Cuando cambia `A`, `RD` se actualiza en el mismo ciclo
  (considerando el retardo de propagación).

### Diseño y Justificación

La lectura asíncrona es una decisión arquitectónica deliberada:

- En el pipeline RV32I:
  - La dirección se genera en la etapa MEM.
  - El dato debe estar disponible antes del flanco de escritura en WB.
- Si la lectura fuera síncrona:
  - Se necesitaría un ciclo extra
  - O un stall del pipeline

Al usar lectura combinacional:
- Se evita latencia adicional
- Se mantiene eficiencia del pipeline

En FPGA Artix-7, el sintetizador puede inferir:
- BRAM en modo read-first
- O distributed RAM

Ambas permiten lectura asíncrona.

# ROM: Memoria de Instrucciones (IM)

---

## Módulo: Arreglo de Instrucciones (`IM`)

**Nombre:**  
`IM` — Arreglo ROM de instrucciones de 32 bits

**Objetivo:**  
Almacenar el programa compilado (instrucciones RV32I) de forma permanente durante la ejecución.

Es una **ROM**:
- Solo lectura
- Nunca se escribe en tiempo de ejecución

**Entradas:**  
- Ninguna directa (se carga mediante `$readmemh` en síntesis/simulación)

**Salidas:**  
- Contenido de la posición indexada (hacia la lógica de lectura)

**Relación:**  
Es el recurso central del módulo.  
La lógica de lectura accede a él directamente de forma combinacional.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/ROM1.png?ref_type=headss" width="430">

### Funcionamiento

Se declara como:
`logic [31:0] IM [0:2047]`


- 2048 palabras de 32 bits
- 2¹¹ = 2048 posiciones

En simulación (y síntesis compatible):
- El bloque `initial` carga el archivo `.hex`
- Una vez cargado, su contenido no cambia

### Diseño

- No tiene `WE`
- No tiene reset
- No existe `always_ff` de escritura

El sintetizador lo infiere como **ROM**.

En FPGA Artix-7 puede mapearse a:
- BRAM en modo ROM
- LUTs si el tamaño lo permite

---

## Módulo: Inicialización desde archivo `.hex` (`initial`)

**Nombre:**  
Bloque `initial` — carga de programa

**Objetivo:**  
Inicializar el arreglo `IM` con el programa compilado antes de iniciar ejecución o simulación.

**Entradas:**  
- Archivo externo `programa.hex`

**Salidas:**  
- Arreglo `IM` completamente inicializado

**Relación:**  
Es el único mecanismo de “escritura” del módulo.  
Ocurre una sola vez al inicio.

Después de esto, `IM` es de solo lectura para el resto del sistema.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/ROM2.png?ref_type=heads" width="430">

### Funcionamiento

Se utiliza la tarea del sistema:
`$readmemh("programa.hex", IM);`

Proceso:

- Lee el archivo línea por línea
- Cada línea representa un valor hexadecimal de 32 bits
- Se carga en orden:  
  `IM[0], IM[1], IM[2], ...`

Si el archivo contiene menos de 2048 instrucciones:

- En simulación → posiciones restantes quedan indefinidas
- En síntesis → típicamente se inicializan en cero

### Diseño

El bloque `initial`:
- No genera hardware físico
- Es una directiva de inicialización

En síntesis (Vivado):
- El contenido del `.hex` se convierte en valores de inicialización de BRAM o LUTs
- Queda grabado en el bitstream final

---

## 3. Módulo: Lectura Combinacional (`assign instruction`)

**Nombre:**  
Lectura asíncrona de instrucción

**Objetivo:**  
Entregar inmediatamente la instrucción apuntada por `address`, sin esperar reloj.

Es el camino crítico del **Instruction Fetch** del pipeline.

**Entradas:**  
- `address[12:2]`
- Contenido de `IM`

**Salidas:**  
- `instruction[31:0]` → hacia el registro IF/ID

**Relación:**  
Alimenta directamente la primera etapa del pipeline (IF).  
La rapidez de esta lectura afecta el periodo máximo de reloj.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/ROM3.png?ref_type=heads" width="430">

### Funcionamiento

Implementado con:
`assign instruction = IM[address[12:2]];`


- Camino puramente combinacional
- No interviene ningún reloj
- Cuando cambia `address` (actualización del PC),
  `instruction` cambia en el mismo ciclo
  (considerando retardo de acceso a memoria)

---

### Justificación del uso de `address[12:2]`

| Bits | Uso | Razón |
|------|------|--------|
| `[1:0]` | Descartados | Instrucciones alineadas a 4 bytes |
| `[12:2]` | Índice (11 bits) | 2¹¹ = 2048 posiciones |
| `[31:13]` | Ignorados | Fuera del rango de la ROM |

---

## Diseño y Justificación General

Al igual que en la RAM de datos:

- La lectura asíncrona evita agregar latencia al pipeline.
- Permite que la instrucción esté disponible dentro del mismo ciclo de fetch.

Diferencia clave con `data_memory`:

- No existe lógica de escritura en tiempo de ejecución.
- El módulo se reduce a:
  - Cargar una vez
  - Leer siempre

Esto simplifica la estructura y permite al sintetizador optimizarlo claramente como una **ROM pura**, habilitando mejores optimizaciones en FPGA.

# Módulo – CPU RISC-V RV32I

---

## Nombre del módulo

`riscv_cpu` — Procesador RISC-V de 32 bits (subconjunto RV32I)

---

## Objetivo

Ejecutar instrucciones del subconjunto **RV32I** de forma secuencial y determinista, gestionando:

- Flujo de control (PC y saltos)
- Banco de registros
- Unidad aritmético-lógica (ALU)
- Interfaz con memoria de programa (ROM)
- Interfaz con memoria/periféricos (bus de datos)

---

## Entradas

| Señal        | Ancho | Descripción |
|-------------|--------|------------|
| `clk_i`      | 1      | Reloj del sistema |
| `rst_i`      | 1      | Reset síncrono activo alto |
| `ProgIn_i`   | 32     | Instrucción leída de ROM |
| `DataIn_i`   | 32     | Dato leído de RAM o periférico |

---

## Salidas

| Señal            | Ancho | Descripción |
|------------------|--------|------------|
| `ProgAddress_o`  | 32     | Dirección del PC hacia ROM |
| `DataAddress_o`  | 32     | Dirección de acceso a datos |
| `DataOut_o`      | 32     | Dato a escribir en RAM/periférico |
| `we_o`           | 1      | Write enable hacia bus de datos |

---

## Relación con otros módulos

El CPU es el núcleo central del sistema.

- Lee instrucciones desde la **Program Memory (ROM)** mediante el bus de programa.
- Lee y escribe datos en:
  - Data Memory (RAM)
  - Periféricos (PWM, ADC, VGA, UART, GPIO)

Todo a través del **bus de datos unificado** y el `address decoder`.

---

## Explicación General de Funcionamiento

El CPU implementa un pipeline de 5 etapas simplificado (o arquitectura monociclo/multiciclo según implementación).

En cada ciclo:

1. **Fetch**: Obtiene instrucción desde ROM usando el PC.
2. **Decode**: Identifica operación y operandos.
3. **Execute**: Opera en la ALU.
4. **Memory**: Accede a RAM si la instrucción lo requiere.
5. **Writeback**: Escribe resultado en el banco de registros.

El PC se actualiza:
- Secuencialmente (`PC + 4`)
- O mediante salto/branch

---

## Submódulo – Program Counter (PC)

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/CPU1.png" width="450">

### Diseño del PC

- Registro de 32 bits
- Implementado con **32 flip-flops tipo D en paralelo**
- MUX 2:1 de 32 bits selecciona entre:
  - `32'h0` (reset)
  - `pc_next_i`

`rst_i` actúa como señal `sel` del MUX.

En cada flanco positivo:
- El FF captura el valor de entrada D.
- La salida Q alimenta:
  - Sumador `PC + 4`
  - Sumador de saltos
- El resultado vuelve como `pc_next_i`.

---

## Submódulo – Instruction Decoder

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/CPU2.png" width="430">
### Diseño

Lógica puramente combinacional.

Extracción directa mediante asignaciones:

- `rs1 = IR[19:15]`
- `rs2 = IR[24:20]`
- `rd  = IR[11:7]`
- `opcode = IR[6:0]`
- `funct3 = IR[14:12]`
- `funct7 = IR[31:25]`

Los inmediatos se reconstruyen según tipo de instrucción:
- Concatenación de campos
- Extensión de signo

---

## Submódulo – Unidad de Control

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/CPU3.png" width="450">

### Diseño

Bloque combinacional:
`always_comb`
`case(opcode)`


Cada rama del `case` asigna todas las señales de control.

Es obligatorio:

- Inicializar todas las señales en 0 al inicio del bloque
- Evitar inferencia de latches en síntesis

---

## Submódulo – ALU de 32 bits

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/CPU4.png" width="430">

### Diseño de la ALU

Núcleo aritmético:

- Sumador de 32 bits
  - Ripple-carry o carry-lookahead

Resta implementada con complemento a 2:

`B_inv = B XOR {32{sub}}`
`sum = A + B_inv + sub`


Desplazamiento aritmético:

- Uso de `>>>`
- Operandos declarados como `signed`

Selección final:

- MUX de 8 entradas
- Controlado por `alu_op[2:0]`

---

## Submódulo – Banco de Registros

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/CPU5.png" width="450">

### Diseño

- 32 registros de 32 bits
- Registro x0 cableado permanentemente a 0
- Dos puertos de lectura combinacionales
- Un puerto de escritura síncrono
- Escritura habilitada por `reg_write`

---

## Submódulo – Sign Extender

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/CPU6.png" width="430">

### Diseño

Bloque combinacional.

Reconstruye inmediatos según tipo:

- I-type
- S-type
- B-type
- U-type
- J-type

Replica el bit más significativo para extensión de signo.

---

## Submódulo – Address Decoder

Este módulo no está dentro del CPU, pero es parte central del sistema.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/CPU7.png" width="430">

### Función

- Decodifica `DataAddress_o`
- Determina si el acceso corresponde a:
  - RAM
  - UART
  - PWM
  - ADC
  - VGA
  - GPIO

Genera:

- Señales de habilitación específicas
- Enrutamiento correcto del `DataIn_i`

---



# Módulo – Periférico ADC / XADC

---

## Nombre del módulo

`adc_peripheral` — Wrapper del bloque IP XADC Wizard de Vivado, expuesto como periférico mapeado en memoria de 32 bits.

---

## Objetivo

Servir de puente entre:

- El bus del CPU (registros de control/estado/dato)
- El bloque analógico XADC embebido en el Artix-7

Este módulo **no implementa el ADC desde cero**.  
Instancia el IP `xadc_wiz_0` generado por Vivado y gestiona su protocolo de handshake:

- Inicio de conversión  
- Espera de fin  
- Lectura de dato válido  

Todo esto hacia el CPU.

---

## IP Catalog vs Diseño Propio

Esta es la diferencia clave respecto al PWM.

- El **XADC** es un bloque analógico-digital físico dentro de la FPGA.
- Vivado lo expone mediante el **XADC Wizard IP**.
- Ese IP genera un wrapper digital con interfaz **DRP (Dynamic Reconfiguration Port)**.

Se diseñó un **segundo wrapper** que convierte la interfaz DRP en registros mapeados en memoria accesibles por el RISC-V.

---

## Entradas y Salidas del Módulo

| Señal | Dir | Ancho | Descripción |
|--------|-----|--------|-------------|
| `clk_i` | in | 1 | Reloj del sistema (100 MHz) |
| `rst_i` | in | 1 | Reset síncrono |
| `addr_i` | in | 32 | Dirección bus de datos |
| `wdata_i` | in | 32 | Dato a escribir |
| `we_i` | in | 1 | Write enable |
| `cs_i` | in | 1 | Chip select |
| `adc_start_ext_i` | in | 1 | Disparo externo de conversión |
| `pwm_trigger_i` | in | 1 | Disparo automático desde PWM |
| `rdata_o` | out | 32 | Dato leído por CPU |

---

## Relación con Otros Módulos

El `adc_peripheral` es el único módulo con frontera analógica.

- Recibe señal analógica desde divisor resistivo conectado a `VAUXP/VAUXN`.
- Instancia el IP XADC para realizar la conversión.
- Entrega el resultado digital (`adc_data[11:0]`) al CPU.

Además:

- `pwm_trigger_i` proviene del `pwm_peripheral`
- Permite sincronizar muestreo con el ciclo de conmutación

---

# Submódulos Internos

---

## Submódulo – IP XADC Wizard y la Interfaz DRP

Antes de diseñar el wrapper, se debe entender la interfaz del IP generado por Vivado.

Este bloque **no es código propio**, es hardware predefinido.

Interfaz relevante: **DRP (Dynamic Reconfiguration Port)**

Características clave:

- Dirección DRP `7'h10` → Registro del canal AUX0
- `0x11` → AUX1, etc.
- Fin de conversión indicado por pulso `eoc_out`
- Lectura se realiza mediante transacción DRP inmediatamente después de `eoc_out`

---

## Submódulo – Registros Mapeados en Memoria del ADC

**Registro 0 - ctrl/estado**
<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/ADC1.png" width="430">

**Registro 1 - dato convertido**
<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/ADC2.png" width="430">

**start [0] W1P:**
Write-1-to-Pulse. Escribir 1 dispara 1 conversión. Se auto-limpia al siguiente ciclo.

**new_data [1] RW1C:**
Se pone a 1 cuando llega dato nuevo. CPU lo limpia escribiendo 1 (Write-1-to-Clear).

**ext_start_en [2]:**
Habilita el pin adc_start_ext_i como fuente de disparo externo.

**busy [3] RO:**
Refleja busy_out del XADC. CPU puede pollear para saber si conversión terminó.

**pwm_trig_en [4]:**
Habilita pwm_trigger_i como fuente de disparo automático sincronizado.

Estos registros permiten al CPU:
- Habilitar disparos
- Iniciar conversión
- Leer resultado digital
- Consultar flags de estado

---

## Submódulo – FSM de Control DRP (Corazón del Wrapper)

Esta es la parte diseñada manualmente.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/ADC3.png" width="430">

### Función

La FSM implementa el protocolo requerido por el IP XADC:

1. Esperar trigger
2. Iniciar conversión
3. Esperar `eoc_out`
4. Ejecutar lectura DRP
5. Capturar dato
6. Actualizar registro de estado

La FSM traduce el protocolo DRP en una interfaz simple tipo:

- `start`
- `data_ready`
- `data_out`

para el CPU.

---

## Submódulo – Lógica de Disparo (Trigger MUX)

Tres fuentes de disparo:

- Bit de control por CPU
- `adc_start_ext_i`
- `pwm_trigger_i`

Se combinan mediante lógica OR, habilitadas individualmente por bits de control.

**Trigger mux y diagrama temporal**
<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/ADC4.png" width="430">

**Diagrama temporal - ciclo de conversión completo**

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/ADC5.png" width="430">

---

# Diseño

Gran diferencia respecto a otros módulos:

No se diseñan compuertas para el ADC en sí.  
El ADC ya existe físicamente en el chip.

Lo que se diseña es:

- Wrapper digital
- FSM de control
- Registros mapeados
- Lógica de disparo

---

# Escalamiento Analógico (Diseño Crítico)

El XADC de la FPGA acepta máximo **1.0 V** en entradas auxiliares.

Si:

- `Vout = 24 V`

Se requiere divisor resistivo:
`Vdiv = Vout × R2 / (R1 + R2)V`


Ejemplo:

- `R1 = 23 kΩ`
- `R2 = 1 kΩ`

Entonces:

`Vdiv = 24 × (1 / 24) = 1.0 V`

Valor límite seguro para el XADC.

En software:

El CPU multiplica el resultado digital por 24 para reconstruir `Vout`.

---

# Módulo — Periférico PWM

## Nombre del módulo

**pwm_peripheral** — Generador PWM mapeado en memoria, 32 bits, con interfaz de registros de control/estado y ciclo de trabajo.

---

## Objetivo

Generar una señal PWM de frecuencia y ciclo de trabajo programables por software, exponiendo dos registros de 32 bits accesibles desde el CPU.  

Además, produce una señal de sincronización `pwm_trigger_o` al inicio de cada período, usada para disparar conversiones ADC alineadas con la conmutación.

---

## Entradas

| Señal   | Ancho | Descripción |
|----------|--------|-------------|
| clk_i    | 1      | Reloj del sistema (100 MHz) |
| rst_i    | 1      | Reset síncrono activo alto |
| addr_i   | 32     | Dirección del bus de datos |
| wdata_i  | 32     | Dato a escribir (desde el CPU) |
| we_i     | 1      | Write enable del bus |
| cs_i     | 1      | Chip select (desde el address decoder) |

---

## Salidas

| Señal          | Ancho | Descripción |
|----------------|--------|-------------|
| rdata_o        | 32     | Dato leído por el CPU |
| pwm_out_o      | 1      | Señal PWM de potencia hacia el gate driver |
| pwm_trigger_o  | 1      | Pulso de sincronización al inicio del período PWM |

---

## Relación con otros módulos

Recibe escrituras del CPU (configuración de frecuencia, enable y duty cycle).  

Su salida `pwm_out_o` controla el MOSFET del convertidor boost a través del gate driver.  

La señal `pwm_trigger_o` va al periférico ADC/XADC para alinear el muestreo con el inicio del período PWM, eliminando el jitter entre medición y actuación.

---

## Funcionamiento

Internamente contiene un contador libre que cuenta de 0 hasta un valor `PERIOD-1` determinado por `freq_sel`.

Cuando el contador es menor que el valor de comparación: `(duty_pct × PERIOD) / 100`


la salida PWM es alta; en caso contrario, es baja.

El trigger se genera como un pulso de 1 ciclo cuando el contador llega a 0 (inicio de período).

---

# Diseño — Justificación de frecuencias

Para un reloj de 100 MHz y una frecuencia de conmutación fsw > 20 kHz, se usan tres valores de período:

| freq_sel | Frecuencia | PERIOD (cuentas) | Resolución duty |
|-----------|------------|------------------|-----------------|
| 2'b00     | 25 kHz     | 4000             | 0.025 % / paso |
| 2'b01     | 50 kHz     | 2000             | 0.05 % / paso  |
| 2'b10     | 100 kHz    | 1000             | 0.1 % / paso   |

La resolución del duty se calcula como:`round(duty_pct × PERIOD / 100)`


saturando el resultado al rango `[0, PERIOD]`.

---

# Submódulo — Registros mapeados en memoria  
(bus interface + register file)

Diseño de los dos registros de 32 bits y su decodificación de dirección.

---

## Registro 0 — ctrl/estado

Dirección: `0x0001_0100`  
Offset: `0x00`

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/PWM1.png" width="430">

- `running` → RO, refleja el estado del contador activo.

---

## Registro 1 — Ciclo de trabajo (duty)

Dirección: `0x0001_0104`  
Offset: `0x04`

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/PWM2.png" width="430">

---

# Submódulo 2 — Contador libre de período

Este es el corazón del generador PWM.  

Es un contador que cuenta de `0` a `PERIOD-1` y vuelve a `0`.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/PWM3.png" width="500">

### Diseño del contador

- Registro de 13 bits (necesario para representar hasta 4000).
- Sumador de incremento.
- Comparador contra `PERIOD-1`.
- MUX de selección (wrap o incremento).

En cada flanco de reloj:

- Si `cnt == PERIOD-1` → se carga `0`.
- Si no → se carga `cnt + 1`.
- Si `rst` está activo → se carga `0`.
- Si `enable = 0` → el contador se congela.

---

# Submódulo — Comparador de duty cycle y compuerta de salida

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/PWM4.png" width="700">

---

# Submódulo — Generador de trigger y máquina de estados del PWM

El trigger y la señal `running` se implementan con lógica adicional.

<img src="https://gitlab.com/grupo034420017/proyecto03/-/raw/main/doc/Imagenes%20Documentaci%C3%B3n/PWM5.png" width="700">

El trigger es puramente combinacional: es 1 solo cuando cnt==0 AND enable==1.
Como cnt==0 dura exactamente 1 ciclo de reloj, el trigger es naturalmente un pulso de 1 ciclo.
No necesita registro adicional: la duración está garantizada por el ciclo del contador.

Salidas del módulo y su origen

`pwm_out_o`
= (cnt < threshold) AND enable
`pwm_trigger_o`
= (cnt == 0) AND enable
`running (bit 3)`
= enable (refleja estado activo del generador)
`rdata_o`
= {28'b0, running, freq_sel, enable} (addr==0x100)

---

# Diseño — Señales internas

| Señal          | Tipo            | Ecuación / Descripción |
|----------------|----------------|------------------------|
| cnt_next       | Combinacional  | `(cnt == PERIOD-1) ? 0 : cnt + 1` |
| threshold      | Combinacional  | `(duty_pct * PERIOD) / 100` (la división por 100 se sintetiza como shifts + sumas) |
| pwm_raw        | Combinacional  | `cnt < threshold` (restador, bit de borrow) |
| pwm_out_o      | Combinacional  | `pwm_raw AND enable` |
| pwm_trigger_o  | Combinacional  | `(cnt == 0) AND enable` — NOR de 13 bits del contador |
| running        | Registro (RO)  | `enable` — registrado para lectura coherente |
| duty_pct       | Registro (R/W) | Saturación: `wdata[6:0] > 100 ? 100 : wdata[6:0]` |

---


