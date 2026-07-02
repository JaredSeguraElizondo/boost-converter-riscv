# Closed-Loop DC-DC Boost Converter on a RISC-V Soft-Core

## Overview

This project combines computer organization, memory-mapped peripheral design, and VGA visualization to build an embedded power-control system from the ground up.

The platform is a custom FPGA-based digital system built around a 32-bit RISC-V core (RV32I) with separate program and data memories and a set of purpose-built peripherals. The application implements closed-loop control of a DC-DC boost converter: the processor runs the control algorithm and manages acquisition (ADC), actuation (PWM), display (VGA), and communication (UART) peripherals.

A boost converter steps up an input DC voltage — common in battery-powered systems, PV panels, and LED drivers. Because load and source variations affect the output, feedback control is essential for stability and performance.

Rather than using a commercial microcontroller, this project replicates an industrial embedded-control workflow on a from-scratch RISC-V system with custom digital peripherals — CPU, memory map, and control loop all designed and verified in-house.

**Full technical report (Spanish):** see [`/doc`](./doc) for the complete written report, including derivations, additional test data, and build documentation.

---

## Background & Design Foundations

Key concepts researched and applied in this design:

1. **RV32I + memory-mapped I/O** — a 32-bit RISC ISA with a 32-bit address bus; peripherals (PWM, ADC, UART, VGA) are accessed like ordinary memory addresses rather than through dedicated I/O instructions.
2. **32-bit peripheral register model** — every peripheral exposes control, status, and data registers at fixed offsets, decoded by the central address decoder.
3. **PWM fundamentals** — duty cycle vs. frequency vs. resolution trade-offs (`f = clk / period`, `duty = compare_count / period`).
4. **XADC on Artix-7** — 12-bit analog-to-digital conversion via the Dynamic Reconfiguration Port (DRP): start conversion → poll End-of-Conversion → read result.
5. **Closed-loop boost control** — sample `Vout` → compute error `e = Vref − Vmeasured` → PI controller → update PWM duty cycle, repeated every sampling period.
6. **640×480 @ 60 Hz VGA** — HSYNC/VSYNC timing generation plus a sample buffer scanned against the beam position to plot real-time voltage/current curves.
7. **UART 115200 8N1** — asynchronous serial framing (8 data bits, no parity, 1 stop bit; ~8.68 µs/bit).
8. **Averaged small-signal modeling** — the boost converter's linearized transfer function `G(s)` has a right-half-plane zero (non-minimum phase) and a complex pole pair set by L, C, and load — the basis for controller design and stability analysis.
9. **PI controller design** — `C(s) = Kp + Ki/s`, tuned from the plant model for adequate phase margin (typically > 45°) using Bode/root-locus analysis.
10. **Discretization** — the continuous-time PI controller is discretized (Tustin/bilinear preferred) for digital implementation; sampling rate must be ~10–20× faster than the loop bandwidth to avoid destabilizing phase lag.
11. **Experimental validation** — step response, load-disturbance rejection, and settling-time/overshoot/steady-state-error metrics, compared against the averaged model (via VGA or UART streaming to Python/matplotlib).

---

## Peripherals

### `uart_peripheral`
Bridges the CPU clock domain and the UART clock domain, with 2- and 3-stage synchronizers for clock-domain crossing (CDC).

**Ports**

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk_cpu_i` / `rst_cpu_i` | in | 1 | CPU domain clock / reset |
| `write_enable_i` | in | 1 | MMIO write enable |
| `addr_i` | in | 2 | Register address |
| `wdata_i` / `rdata_o` | in/out | 32 | MMIO data |
| `clk_uart_i` / `rst_uart_i` | in | 1 | UART domain clock / reset |
| `RsRx` / `RsTx` | in/out | 1 | Serial lines |

**Register map**

| `addr_i` | Access | Bit | Description |
|---|---|---|---|
| `2'b00` | R/W | `[0]` | `reg_send` — write `1` to start a transmission |
| `2'b00` | R/W | `[1]` | `reg_new_rx` — write `1` to clear the "data received" flag |
| `2'b00` | R | `[2]` | `tx_busy` — `1` while a transmission is in progress |
| `2'b01` | R/W | `[7:0]` | `reg_data_tx` — byte to transmit |
| `2'b10` | R | `[7:0]` | `reg_data_rx` — last received byte |

Design notes: `reg_send` is synchronized into the UART domain with a 2-stage register; `tx_rdy`/`rx_rdy` are synchronized back with 3-stage edge detectors. Wraps an internal serial `UART` core.

### `gpio_peripheral`
Reads a physical button, synchronizes it (double flip-flop), and applies a 20 ms debounce filter (`DEBOUNCE_MAX = 2,000,000` cycles @ 100 MHz) before exposing `rdata_o[0]`.

### `adc_xadc_mmio`
Wraps the Xilinx XADC IP via its DRP port. Lets the CPU trigger conversions, read 12-bit results, and select the trigger source (external signal or PWM sync pulse).

**Register map**

| Offset | Bits | Access | Description |
|---|---|---|---|
| `0x0` | `[0]` | W | `start` — trigger a conversion (1-cycle pulse) |
| `0x0` | `[1]` | R/W | `new_data` — result ready (RW1C) |
| `0x0` | `[2]` | R/W | `ext_start_en` — enable external trigger |
| `0x0` | `[3]` | R | `busy` — conversion in progress |
| `0x0` | `[4]` | R/W | `pwm_trig_en` — enable PWM-synced trigger |
| `0x4` | `[11:0]` | R | 12-bit ADC result (`new_data` auto-clears on read) |

FSM: `IDLE → READ_DRP → WAIT_DRDY → IDLE`, waiting for `eoc_i` before pulsing `den_o` and capturing the result on `drdy_i`.

### `risc_v_cpu`
32-bit RV32I core implementing `lw`/`sw`, arithmetic/logic (register and immediate), shifts, branches, `jal`, and `jalr` on a Harvard architecture with independent program/data buses. Internally organized as 5 stages: Fetch, Decode, Execute, Memory, Writeback. Reset vectors the PC to `0x0000_0000`. Submodules (PC, decoder, ALU, register file, sign extender, control unit) are documented in `/doc`.

### `data_memory`
1024×32-bit RAM with combinational read and synchronous write. Synchronous reset (priority over write) clears all locations to zero.

### `pwm_peripheral`
Memory-mapped PWM generator with control/status and duty-cycle registers. Emits a `pwm_trigger_o` pulse at the start of every period so the ADC can align conversions with the converter's switching.

**Register map**

| Offset | Bits | Access | Description |
|---|---|---|---|
| `0x00` | `[0]` | R/W | `enable` |
| `0x00` | `[2:1]` | R/W | `freq_sel` (3 valid values) |
| `0x00` | `[3]` | R | `running` |
| `0x04` | `[6:0]` | R/W | `duty_pct` (0–100, saturates above 100) |

**Configurable frequencies** (100 MHz base clock, chosen above the audible range):

| `freq_sel` | Frequency | Period (counts) |
|---|---|---|
| `2'b00` | 25 kHz | 4000 |
| `2'b01` | 50 kHz | 2000 |
| `2'b10` | 100 kHz | 1000 |

The internal counter runs `0 → PERIOD-1`; output is high while `cnt < threshold`, with `threshold = duty_pct × PERIOD / 100`. The trigger pulse is `(cnt == 0) AND enable`, guaranteeing exactly one cycle per period.

---

## System Integration

All peripherals share a common `write_enable` / `addr` / `wdata`-`rdata` bus interface, arbitrated by a central address decoder in the project's TOP module.

---

## Verification

### VGA peripheral
Two complementary testbenches were used:

- **TB1 (`tb_vga_periph.sv`)** — self-checking, 8 tests (T1–T8) covering reset, control register, HSYNC/VSYNC timing, blanking, and green-pixel detection. **Result: 19/19 assertions passed.**
- **TB2 (`tb_vga_visual.sv`)** — a diagnostic bench built after TB1 initially failed to catch the plotted pixel. It fills the whole sample buffer with one ADC value and checks the exact cycle count and timing of the resulting scanline. **Result: 4/4 assertions passed.**

| Test | Check | Result |
|---|---|---|
| T1 | HSYNC/VSYNC/RGB held at reset | PASS |
| T2 | Control register write/readback | PASS |
| T3 | HSYNC period = 32,000 ns | PASS |
| T4 | HSYNC pulse width = 3,840 ns | PASS |
| T5 | VSYNC period = 16,800,000 ns | PASS |
| T6 | RGB = 0 during H-blanking | PASS |
| T7 | Green pixel rendered on the correct row | PASS |
| T8 | Sync/RGB behavior on disable | PASS |
| TB2 | 640/640 cycles with `grn=F` on the target row | PASS |

**Debugging note:** TB1's original monitoring window for T7 was sized from the wrong VSYNC edge and undershot the frame by ~27,000 cycles — a testbench coverage bug, not a hardware defect. Widening the window to a full frame (`V_TOTAL × H_TOTAL`) fixed it, and TB2 independently confirmed the peripheral was correct all along, down to the exact pixel timing.

### UART peripheral
Three tests: transmitting `"Hi\n"`, transmitting `"512\r\n"` (multi-byte with line terminators), and reading back all three register addresses post-transmission to confirm status/data consistency. All passed.

### PWM peripheral
- **Frequency sweep** at fixed 50% duty (25/50/100 kHz): period changes correctly between regions with duty symmetry preserved, confirming the counter and threshold rescale properly on `PERIOD` changes.
- **Duty sweep** at fixed 50 kHz (45% → 60% in 5% steps): pulse width scales proportionally while the period stays constant at 20 µs; the sync trigger fires exactly once per period.

### Full integrated CPU
CPU + ROM + RAM + peripheral mocks (fixed ADC = 0x800, button always pressed, UART never busy) running the actual control-loop firmware. Waveform trace confirms sequential PC advance (`+4`/cycle) and captures the expected sequence of MMIO writes: enabling PWM, setting initial duty, configuring/triggering the ADC, enabling VGA, and — critically — the controller updating `PWM_DUTY` from 50% to 51% based on a live ADC reading, then pushing the scaled sample to the VGA buffer. This confirms the full acquisition → control → actuation → display loop executes correctly end to end.

### Limitations
The design was verified in simulation only; it was not validated on real hardware within the scope of this project.

---

## Repository Structure

- RTL: `risc_v_cpu`, `uart_peripheral`, `gpio_peripheral`, `adc_xadc_mmio`, `pwm_peripheral`, `data_memory`, VGA render/sync modules, and the TOP-level integration/decoder.
- Testbenches for each peripheral plus the integrated CPU.
- `/doc` — full written report (Spanish), including derivations, additional waveforms, and build/construction documentation.
