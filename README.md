# Proyecto03

## Introducción

Este proyecto integra conceptos de organización de computadores, periféricos mapeados en memoria y visualización en VGA para implementar un sistema embebido de control de potencia.

La plataforma consiste en un sistema digital en FPGA con un procesador RISC-V de 32 bits (rv32i), memorias separadas para programa y datos, y periféricos específicos. La aplicación desarrolla el control en lazo cerrado de un convertidor DC-DC tipo boost, donde el procesador ejecuta el algoritmo de control y gestiona módulos de adquisición (ADC), actuadores (PWM), visualización (VGA) y comunicación (UART).

El convertidor boost se utiliza para elevar una tensión DC de entrada, siendo común en aplicaciones como sistemas con baterías, paneles fotovoltaicos y drivers LED. Debido a que variaciones en la carga o la fuente afectan la salida, el control con realimentación es esencial para garantizar estabilidad y buen desempeño.

Este proyecto replica el enfoque industrial de control embebido, pero diseñando desde cero un sistema basado en RISC-V y periféricos digitales, en lugar de usar un microcontrolador comercial.

# Documentación del Proyecto

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

## 2. Sincronizador `reg_send → tx_start_uart` (CPU → UART)

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

## 3. Sincronizador + Detector de Flanco `tx_rdy` (UART → CPU)

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

## 4. Sincronizador + Detector de Flanco `rx_rdy` (UART → CPU)

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

## 5. Registros de Control / Estado (dominio CPU)

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

## 6. Bus de Lectura (lógica combinacional `rdata_o`)

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



