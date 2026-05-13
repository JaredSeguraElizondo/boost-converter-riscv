"""
uart_to_csv.py
==============
Recibe las muestras del ADC enviadas por el UART desde la FPGA y las
guarda en un archivo CSV con la tension reconstruida.
"""

import argparse
import csv
import sys
import time
from datetime import datetime

try:
    import serial
except ImportError:
    print("ERROR: falta la libreria pyserial.")
    print("Instalala con:  pip install pyserial")
    sys.exit(1)


# Ajustar los valores según nuestros elementos
LSB_VOLT = 1.0 / 4096
DIVISOR  = 30.0


def main():
    parser = argparse.ArgumentParser(
        description="Recibe muestras del UART desde la FPGA y guarda CSV"
    )
    parser.add_argument(
        "--puerto",
        required=True,
        help="Puerto serie (ej: COM5 en Windows, /dev/ttyUSB0 en Linux)",
    )
    parser.add_argument(
        "--baudrate",
        type=int,
        default=115200,
        help="Velocidad de transmision (default: 115200)",
    )
    parser.add_argument(
        "--n",
        type=int,
        default=512,
        help="Numero de muestras a recibir (default: 512)",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=3.0,
        help="Timeout en segundos sin recibir datos (default: 3.0)",
    )
    parser.add_argument(
        "--csv",
        default=None,
        help="Nombre del archivo CSV (default: muestras_<fecha>.csv)",
    )
    args = parser.parse_args()

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    archivo_csv = args.csv or f"muestras_{timestamp}.csv"

    print("=" * 60)
    print(f" Recepcion UART desde FPGA - {timestamp}")
    print("=" * 60)
    print(f" Puerto       : {args.puerto}")
    print(f" Baudrate     : {args.baudrate}")
    print(f" Muestras max : {args.n}")
    print(f" Timeout      : {args.timeout} s")
    print(f" Archivo CSV  : {archivo_csv}")
    print(f" Conversion   : LSB={LSB_VOLT*1000:.4f} mV, divisor={DIVISOR}:1")
    print("=" * 60)
    print()

    print(f"Abriendo puerto {args.puerto}...")
    try:
        ser = serial.Serial(args.puerto, args.baudrate, timeout=args.timeout)
    except serial.SerialException as e:
        print(f"ERROR: no se pudo abrir el puerto: {e}")
        print("\nVerifica que:")
        print("  - La FPGA este conectada por USB")
        print("  - El puerto COM sea correcto (Device Manager en Windows)")
        print("  - Ningun otro programa este usando el puerto (PuTTY, etc)")
        sys.exit(1)

    print("Puerto abierto. Esperando muestras...")
    print("(presiona el boton de la FPGA para iniciar el envio)")
    print("(presiona Ctrl+C para terminar antes)\n")

    muestras = []
    ts_inicio = None
    lineas_no_numericas = 0

    try:
        while len(muestras) < args.n:
            try:
                raw = ser.readline()
            except serial.SerialException as e:
                print(f"\nERROR al leer del puerto: {e}")
                break

            if not raw:
                if muestras:
                    print(f"\nTimeout sin datos nuevos. Asumiendo fin del envio.")
                    break
                else:
                    continue

            linea = raw.decode("utf-8", errors="replace").strip()
            if not linea:
                continue

            try:
                valor = int(linea)
            except ValueError:
                lineas_no_numericas += 1
                if lineas_no_numericas <= 3:
                    print(f"  (linea ignorada, no es numero: '{linea}')")
                continue

            if ts_inicio is None:
                ts_inicio = time.time()

            t_ms = (time.time() - ts_inicio) * 1000.0
            tension = valor * LSB_VOLT * DIVISOR
            muestras.append((t_ms, valor, tension))
            print(f"  [{len(muestras):4d}/{args.n}]  t={t_ms:8.2f} ms"
                  f"  ADC = {valor:5d}   V = {tension:6.3f} V")

    except KeyboardInterrupt:
        print("\n\nInterrumpido por el usuario.")

    finally:
        ser.close()
        print("\nPuerto cerrado.")

    if lineas_no_numericas > 3:
        print(f"\n(en total se ignoraron {lineas_no_numericas} lineas no numericas)")

    if not muestras:
        print("\nNo se recibio ninguna muestra valida.")
        return

    with open(archivo_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["indice", "tiempo_ms", "valor_adc", "tension_v"])
        for i, (t, v, ten) in enumerate(muestras):
            w.writerow([i, f"{t:.3f}", v, f"{ten:.4f}"])

    print(f"\nGuardadas {len(muestras)} muestras en: {archivo_csv}")
    print("Listo.")


if __name__ == "__main__":
    main()
