"""
uart_to_csv.py — version corregida
Recibe muestras del ADC desde el FPGA y reconstruye el voltaje real.

Calibracion corregida con Vref = 0.8 V (medicion real del circuito):
  - XADC: 12 bits, Vref = 0.8V  →  LSB = 0.8 / 4096
  - Divisor resistivo: Vout_max (24V) → 0.8V en pin XADC  →  divisor = 30
  - El pin XADC debe recibir como maximo 0.8V (no superar Vref)

Conversion: Vout = ADC_count * (0.8 / 4096) * 30
  Verificacion: ADC = 3277 → Vout = 3277 * 0.0001953 * 30 = 24.00 V  ✓
  Verificacion: ADC = 4095 → Vout = 4095 * 0.0001953 * 30 = 23.99 V  (fondo de escala = 24V)

IMPORTANTE: Con Vref = 0.8V el rango util del ADC es 0 a 4095 cuentas
para 0 a 0.8V en el pin. El divisor 30:1 mapea 0-24V a 0-0.8V.
NO usar divisor que lleve el pin XADC por encima de Vref (0.8V) o el
ADC satura y las lecturas son incorrectas.
"""

import argparse
import csv
import sys
import time
from datetime import datetime

try:
    import serial
except ImportError:
    print("ERROR: falta pyserial. Instalala con:  pip install pyserial")
    sys.exit(1)


# ============================================================================
# CALIBRACION DEL HARDWARE
# Vref XADC = 0.8V  (medicion real del circuito)
# Divisor resistivo: 30:1  (24V → 0.8V en pin XADC)
# ============================================================================
VREF     = 0.8              # Tension de referencia real del XADC [V]
N_BITS   = 12               # Resolucion del XADC
LSB_VOLT = VREF / (2**N_BITS)   # = 0.8 / 4096 = 0.0001953125 V/count
DIVISOR  = 30.0             # Factor del divisor resistivo externo
# ============================================================================


def main():
    parser = argparse.ArgumentParser(
        description="Recibe muestras ADC del FPGA via UART y guarda en CSV."
    )
    parser.add_argument("--puerto",   default="/dev/ttyUSB0",
                        help="Puerto serie (ej: /dev/ttyUSB0 en Windows, /dev/ttyUSB0 en Linux)")
    parser.add_argument("--baudrate", type=int,   default=115200)
    parser.add_argument("--n",        type=int,   default=512,
                        help="Numero maximo de muestras a recibir")
    parser.add_argument("--timeout",  type=float, default=3.0,
                        help="Timeout de lectura en segundos")
    parser.add_argument("--csv",      default=None,
                        help="Nombre del archivo CSV de salida (auto si no se especifica)")
    args = parser.parse_args()

    timestamp   = datetime.now().strftime("%Y%m%d_%H%M%S")
    archivo_csv = args.csv or f"muestras_{timestamp}.csv"

    # Verificacion de calibracion al iniciar
    adc_24v = round(24.0 / (LSB_VOLT * DIVISOR))

    print("=" * 65)
    print(f" Recepcion UART desde FPGA — {timestamp}")
    print("=" * 65)
    print(f" Puerto           : {args.puerto}")
    print(f" Baudrate         : {args.baudrate} bps")
    print(f" Muestras max     : {args.n}")
    print(f" Archivo CSV      : {archivo_csv}")
    print()
    print(f" Calibracion XADC:")
    print(f"   Vref           = {VREF} V")
    print(f"   Resolucion     = {N_BITS} bits  ({2**N_BITS} cuentas)")
    print(f"   LSB            = {LSB_VOLT*1000:.4f} mV/count")
    print(f"   Divisor        = {DIVISOR}:1")
    print(f"   24V → pinta ADC= {adc_24v} cuentas esperadas")
    print(f"   Verificacion   : ADC={adc_24v} → "
          f"Vout={adc_24v * LSB_VOLT * DIVISOR:.3f} V")
    print("=" * 65 + "\n")

    print(f"Abriendo puerto {args.puerto} a {args.baudrate} bps...")
    try:
        ser = serial.Serial(args.puerto, args.baudrate, timeout=args.timeout)
    except serial.SerialException as e:
        print(f"ERROR al abrir puerto: {e}")
        sys.exit(1)

    print("Puerto abierto. Presiona el boton en la FPGA para iniciar envio...\n")

    muestras             = []
    ts_inicio            = None
    lineas_no_numericas  = 0
    valores_filtrados    = 0

    try:
        while len(muestras) < args.n:
            try:
                raw = ser.readline()
            except serial.SerialException as e:
                print(f"\nERROR al leer puerto: {e}")
                break

            if not raw:
                if muestras:
                    print("\nTimeout — fin del envio desde FPGA.")
                    break
                continue

            # Decodificar con tolerancia a errores de framing UART
            linea = raw.decode("utf-8", errors="replace").strip()
            if not linea:
                continue

            # Solo aceptar lineas puramente numericas (digitos ASCII)
            if not linea.isdigit():
                lineas_no_numericas += 1
                if lineas_no_numericas <= 5:
                    print(f"  (basura ignorada: {repr(linea)})")
                continue

            try:
                valor = int(linea)
            except ValueError:
                continue

            # Filtro de rango: el XADC produce valores 0–4095
            if valor < 0 or valor > 4095:
                valores_filtrados += 1
                print(f"  (valor fuera de rango ignorado: {valor})")
                continue

            if ts_inicio is None:
                ts_inicio = time.time()

            t_ms    = (time.time() - ts_inicio) * 1000.0
            tension = valor * LSB_VOLT * DIVISOR
            muestras.append((t_ms, valor, tension))

            print(f"  [{len(muestras):4d}/{args.n}]  "
                  f"t={t_ms:9.2f} ms   "
                  f"ADC={valor:5d}   "
                  f"Vout={tension:6.3f} V")

    except KeyboardInterrupt:
        print("\nInterrumpido por usuario (Ctrl+C).")
    finally:
        ser.close()
        print("Puerto serie cerrado.")

    # Resumen de datos descartados
    if lineas_no_numericas > 5:
        print(f"\n(ignoradas {lineas_no_numericas} lineas no numericas en total)")
    if valores_filtrados:
        print(f"(filtrados {valores_filtrados} valores fuera de rango 0–4095)")

    if not muestras:
        print("\nNo se recibio ninguna muestra valida. "
              "Verifica la conexion y que el boton fue presionado.")
        return

    # Estadisticas finales
    adc_vals = [v   for _, v, _   in muestras]
    v_vals   = [ten for _, _, ten in muestras]

    print(f"\nEstadisticas ({len(muestras)} muestras validas):")
    print(f"  ADC  : min={min(adc_vals):4d}   max={max(adc_vals):4d}   "
          f"promedio={sum(adc_vals)/len(adc_vals):.1f}")
    print(f"  Vout : min={min(v_vals):.3f} V   max={max(v_vals):.3f} V   "
          f"promedio={sum(v_vals)/len(v_vals):.3f} V")

    # Guardar CSV
    with open(archivo_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["indice", "tiempo_ms", "valor_adc", "tension_v"])
        for i, (t, v, ten) in enumerate(muestras):
            w.writerow([i, f"{t:.3f}", v, f"{ten:.4f}"])

    print(f"\nGuardadas {len(muestras)} muestras en: {archivo_csv}\n")


if __name__ == "__main__":
    main()