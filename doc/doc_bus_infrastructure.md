# Documentación de Diseño Modular — Infraestructura de Bus

## Proyecto 3: Control Digital RISC-V / Convertidor Boost

**Curso:** EL3313 Taller de Diseño Digital  
**Plataforma:** Basys 3 (Artix-7)

---

## 1. Contexto del problema

El microcontrolador RISC-V rv32i utiliza un bus de datos compartido (`DataAddress_o`, `DataOut_o`, `DataIn_i`, `we_o`) para comunicarse tanto con la memoria RAM como con los periféricos mapeados en memoria. Esto genera dos problemas fundamentales que deben resolverse con hardware dedicado:

**Problema de escritura:** Cuando el CPU ejecuta una instrucción `sw` (store word), la señal `we_o` se activa globalmente. Sin un decodificador, todos los dispositivos conectados al bus recibirían la escritura simultáneamente, corrompiendo registros que no eran el destino.

**Problema de lectura:** Cuando el CPU ejecuta `lw` (load word), múltiples dispositivos intentarían colocar sus datos en el bus `DataIn_i` al mismo tiempo, causando contención (cortocircuito lógico). Se necesita un multiplexor que garantice que solo un dispositivo a la vez tenga acceso al bus de lectura.

---

## 2. Mapa de memoria del sistema

El espacio de direcciones de 32 bits se organiza en tres regiones:

```
0x0000_0000 ┌─────────────────────┐
            │   ROM (Programa)    │  8 KB
0x0000_1FFF ├─────────────────────┤
            │     (sin usar)      │
0x0000_2000 ├─────────────────────┤
            │    RAM (Datos)      │  4 KB
0x0000_2FFF ├─────────────────────┤
            │     (sin usar)      │
0x0001_0000 ├─────────────────────┤
            │    Periféricos      │  64 KB (espacio)
0x0001_FFFF └─────────────────────┘
```

### 2.1 Tabla de direcciones de periféricos

| Periférico | Registro            | Dirección       | Tipo  |
|------------|---------------------|-----------------|-------|
| UART       | Control/Estado      | `0x0001_0040`   | R/W   |
| UART       | Datos TX            | `0x0001_0044`   | W     |
| UART       | Datos RX            | `0x0001_0048`   | R     |
| PWM        | Control/Estado      | `0x0001_0100`   | R/W   |
| PWM        | Ciclo de trabajo    | `0x0001_0104`   | R/W   |
| ADC/XADC   | Control/Estado      | `0x0001_0110`   | R/W   |
| ADC/XADC   | Dato convertido     | `0x0001_0114`   | R     |
| VGA        | Control             | `0x0001_0120`   | R/W   |
| VGA        | Datos de plot       | `0x0001_0124`   | R/W   |
| GPIO       | Estado (botón)      | `0x0001_0130`   | R     |

---

## 3. Arquitectura modular

La infraestructura de bus se compone de dos módulos combinacionales que operan en conjunto:

```
                          ┌──────────────────────┐
  DataAddress_o[31:0] ───►│                      │──► sel_o[2:0] ──────────┐
                          │  address_decoder     │──► we_ram_o             │
   we_o ─────────────────►│                      │──► we_uart_o            │
                          │                      │──► we_pwm_o             │
                          │                      │──► we_adc_o             │
                          │                      │──► we_vga_o             │
                          │                      │──► we_gpio_o            │
                          └──────────────────────┘                         │
                                                                           │
                          ┌──────────────────────┐                         │
  data_ram_i[31:0]  ─────►│                      │                         │
  data_uart_i[31:0] ─────►│                      │                         │
  data_pwm_i[31:0]  ─────►│    read_mux          │◄── sel_i[2:0] ─────────┘
  data_adc_i[31:0]  ─────►│                      │
  data_vga_i[31:0]  ─────►│                      │──► data_out_o[31:0] ──► DataIn_i
  data_gpio_i[31:0] ─────►│                      │
                          └──────────────────────┘
```

---

## 4. Módulo `address_decoder`

### 4.1 Interfaz

| Puerto        | Dirección | Ancho  | Descripción                              |
|---------------|-----------|--------|------------------------------------------|
| `address_i`   | Entrada   | 32 bit | Bus de direcciones del CPU               |
| `we_i`        | Entrada   | 1 bit  | Write-enable global del CPU              |
| `sel_o`       | Salida    | 3 bit  | Código de selección para el read_mux     |
| `we_ram_o`    | Salida    | 1 bit  | Write-enable hacia RAM                   |
| `we_uart_o`   | Salida    | 1 bit  | Write-enable hacia UART                  |
| `we_pwm_o`    | Salida    | 1 bit  | Write-enable hacia PWM                   |
| `we_adc_o`    | Salida    | 1 bit  | Write-enable hacia ADC                   |
| `we_vga_o`    | Salida    | 1 bit  | Write-enable hacia VGA                   |
| `we_gpio_o`   | Salida    | 1 bit  | Write-enable hacia GPIO                  |

### 4.2 Codificación de `sel_o`

| `sel_o` | Dispositivo seleccionado |
|---------|--------------------------|
| `3'd0`  | RAM                      |
| `3'd1`  | UART                     |
| `3'd2`  | PWM                      |
| `3'd3`  | ADC/XADC                 |
| `3'd4`  | VGA                      |
| `3'd5`  | GPIO                     |
| `3'd7`  | Ninguno (fuera de rango) |

### 4.3 Estrategia de decodificación

La decodificación se realiza en dos niveles jerárquicos:

**Nivel 1 — Región:** Se comparan los bits superiores de la dirección para distinguir RAM del espacio de periféricos:
- RAM: `address[31:12] == 20'h00002` (rango 0x0000_2xxx)
- Periféricos: `address[31:16] == 16'h0001` (rango 0x0001_xxxx)

**Nivel 2 — Periférico:** Dentro del espacio de periféricos, se compara `address[15:4]` (12 bits) para identificar cuál periférico se está accediendo. Los bits `address[3:0]` quedan libres para seleccionar el registro específico (offset) dentro de cada periférico.

**Caso default:** Si la dirección no coincide con ninguna región o periférico conocido, `sel_o` toma el valor `3'd7` y todos los write-enables permanecen en 0. Esto evita escrituras accidentales y el mux retorna ceros al CPU.

### 4.4 Tabla de verdad del decodificador

| `we_i` | `address_i`                     | `sel_o` | `we_ram` | `we_uart` | `we_pwm` | `we_adc` | `we_vga` | `we_gpio` |
|--------|---------------------------------|---------|----------|-----------|----------|----------|----------|-----------|
| X      | `0x0000_2xxx`                   | `3'd0`  | `we_i`   | 0         | 0        | 0        | 0        | 0         |
| X      | `0x0001_004x`                   | `3'd1`  | 0        | `we_i`    | 0        | 0        | 0        | 0         |
| X      | `0x0001_010x`                   | `3'd2`  | 0        | 0         | `we_i`   | 0        | 0        | 0         |
| X      | `0x0001_011x`                   | `3'd3`  | 0        | 0         | 0        | `we_i`   | 0        | 0         |
| X      | `0x0001_012x`                   | `3'd4`  | 0        | 0         | 0        | 0        | `we_i`   | 0         |
| X      | `0x0001_013x`                   | `3'd5`  | 0        | 0         | 0        | 0        | 0        | `we_i`    |
| X      | cualquier otra                  | `3'd7`  | 0        | 0         | 0        | 0        | 0        | 0         |

Nota: `X` indica que el valor de `we_i` no afecta la selección (`sel_o`), pero sí determina si el write-enable correspondiente se activa o permanece en 0.

### 4.5 Generación de write-enables

Los write-enables individuales se generan mediante AND entre la señal global `we_i` y la señal de selección interna del periférico correspondiente. Esto garantiza que una escritura solo se propaga al dispositivo cuya dirección está en el bus:

```
we_ram_o  = we_i & sel_ram
we_uart_o = we_i & sel_uart
we_pwm_o  = we_i & sel_pwm
we_adc_o  = we_i & sel_adc
we_vga_o  = we_i & sel_vga
we_gpio_o = we_i & sel_gpio
```

---

## 5. Módulo `read_mux`

### 5.1 Interfaz

| Puerto         | Dirección | Ancho  | Descripción                             |
|----------------|-----------|--------|-----------------------------------------|
| `sel_i`        | Entrada   | 3 bit  | Código de selección (del decoder)       |
| `data_ram_i`   | Entrada   | 32 bit | Bus de lectura desde RAM                |
| `data_uart_i`  | Entrada   | 32 bit | Bus de lectura desde UART               |
| `data_pwm_i`   | Entrada   | 32 bit | Bus de lectura desde PWM                |
| `data_adc_i`   | Entrada   | 32 bit | Bus de lectura desde ADC                |
| `data_vga_i`   | Entrada   | 32 bit | Bus de lectura desde VGA                |
| `data_gpio_i`  | Entrada   | 32 bit | Bus de lectura desde GPIO               |
| `data_out_o`   | Salida    | 32 bit | Bus de datos hacia CPU (`DataIn_i`)     |

### 5.2 Comportamiento

El mux es puramente combinacional. Según el valor de `sel_i`, conecta el bus de datos del periférico correspondiente a la salida. Para `sel_i = 3'd7` (fuera de rango o valor no asignado), la salida es `32'h0000_0000`.

---

## 6. Banco de pruebas

El testbench (`tb_bus_infrastructure.sv`) es **autoverificable**: compara automáticamente las salidas de ambos módulos contra valores esperados y reporta PASS/FAIL para cada caso. No requiere inspección visual de waveforms.

### 6.1 Grupos de prueba

| Grupo | Descripción                                     | Cantidad |
|-------|--------------------------------------------------|----------|
| 1     | Lectura (we=0): selección correcta por dirección | 13       |
| 2     | Escritura (we=1): write-enables individuales     | 6        |
| 3     | Direcciones fuera de rango                       | 8        |
| 4     | Exclusividad de write-enables                    | 3        |
| 5     | Transiciones rápidas de dirección                | 2        |

### 6.2 Ejecución

```bash
cd sim/
iverilog -g2012 -o tb_bus tb_bus_infrastructure.sv ../rtl/address_decoder.sv ../rtl/read_mux.sv
vvp tb_bus
```

---

## 7. Consideraciones de diseño

**Latencia:** Ambos módulos son puramente combinacionales. La latencia total del decodificador hasta la aparición del dato en `data_out_o` es de un solo paso combinacional (no introduce ciclos de reloj adicionales). Esto es compatible con la arquitectura Harvard monociclo o pipeline del RISC-V rv32i.

**Escalabilidad:** Para agregar un nuevo periférico, se requiere: (1) agregar su dirección como `localparam` en el decoder, (2) agregar un case en el decoder, (3) agregar su entrada de datos y case en el mux, y (4) extender el ancho de `sel_o` si se superan 6 dispositivos (actualmente 3 bits permiten hasta 7 + default).

**Protección ante escritura fantasma:** El caso `default` en el decoder asegura que si la dirección no coincide con ningún dispositivo conocido, ningún write-enable se activa. Esto protege contra escrituras a registros inexistentes por errores de software.

---

## 8. Estructura de archivos

```
proyecto/
├── rtl/
│   ├── address_decoder.sv      ← Decodificador de direcciones
│   └── read_mux.sv             ← Multiplexor de lectura
├── sim/
│   └── tb_bus_infrastructure.sv ← Banco de pruebas autoverificable
└── doc/
    ├── checkpoint_potencia.md   ← Progreso de la parte de potencia
    └── doc_bus_infrastructure.md ← Este documento
```
