#!/usr/bin/env python3
"""
Mide consumo energetico del CPU Package (RAPL) nativo en Linux,
equivalente al script de PowerShell que usa LibreHardwareMonitor en Windows.

REQUISITOS
    - Ubuntu 22.04 con CPU Intel o AMD compatible con RAPL
    - Verificar antes de usar:
        ls /sys/class/powercap/intel-rapl:0/energy_uj
      Si el archivo no existe, tu CPU no expone RAPL por sysfs.
    - Puede requerir sudo si el archivo no es legible por tu usuario:
        sudo python3 medir_energia_rapl.py -e kraken2_run1

USO
    python3 medir_energia_rapl.py -e "kraken2_run1"
    python3 medir_energia_rapl.py -e "kraken2_run1" -i 1.0
    Ctrl+C para detener cuando el pipeline termine.
"""

import argparse
import csv
import time
import signal
import sys
from datetime import datetime
from pathlib import Path

RAPL_BASE = Path("/sys/class/powercap/intel-rapl:0")
ENERGY_FILE = RAPL_BASE / "energy_uj"
MAX_ENERGY_FILE = RAPL_BASE / "max_energy_range_uj"


def leer_energia_uj():
    """Lee la energia acumulada en microjulios desde el contador RAPL."""
    return int(ENERGY_FILE.read_text().strip())


def leer_max_energia_uj():
    """Valor de overflow del contador (para cuando se reinicia a 0)."""
    try:
        return int(MAX_ENERGY_FILE.read_text().strip())
    except FileNotFoundError:
        return None


def verificar_rapl():
    if not ENERGY_FILE.exists():
        print(f"ERROR: no existe {ENERGY_FILE}", file=sys.stderr)
        print("Tu CPU/kernel no expone RAPL por powercap, o el dominio no es intel-rapl:0.",
              file=sys.stderr)
        print("Prueba: ls /sys/class/powercap/", file=sys.stderr)
        sys.exit(1)
    try:
        leer_energia_uj()
    except PermissionError:
        print(f"ERROR: sin permiso de lectura sobre {ENERGY_FILE}", file=sys.stderr)
        print("Ejecuta el script con sudo, o ajusta permisos con una regla udev.",
              file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Medidor de energia RAPL (equivalente Linux de LHM)")
    parser.add_argument("-e", "--etiqueta", default="run", help="Etiqueta del run (nombre del CSV)")
    parser.add_argument("-i", "--intervalo", type=float, default=1.0, help="Intervalo en segundos")
    args = parser.parse_args()

    verificar_rapl()

    timestamp_archivo = datetime.now().strftime("%Y%m%d_%H%M%S")
    csv_path = f"energia_{args.etiqueta}_{timestamp_archivo}.csv"

    print("=== Medicion de energia iniciada (RAPL / Linux) ===")
    print(f"Etiqueta: {args.etiqueta}")
    print(f"Intervalo: {args.intervalo} s")
    print(f"CSV de salida: {csv_path}")
    print("Presiona Ctrl+C para detener cuando el pipeline termine.\n")

    max_uj = leer_max_energia_uj()
    energia_wh = 0.0
    muestras = 0
    inicio = datetime.now()

    csv_file = open(csv_path, "w", newline="")
    writer = csv.writer(csv_file)
    writer.writerow(["timestamp", "power_w"])

    energia_prev = leer_energia_uj()
    tiempo_prev = time.monotonic()

    detener = {"flag": False}

    def manejar_ctrlc(sig, frame):
        detener["flag"] = True

    signal.signal(signal.SIGINT, manejar_ctrlc)

    try:
        while not detener["flag"]:
            time.sleep(args.intervalo)

            energia_actual = leer_energia_uj()
            tiempo_actual = time.monotonic()

            delta_uj = energia_actual - energia_prev
            # Manejo de overflow: el contador RAPL se reinicia al llegar a max_energy_range_uj
            if delta_uj < 0 and max_uj:
                delta_uj += max_uj

            delta_t = tiempo_actual - tiempo_prev
            watts = (delta_uj / 1_000_000) / delta_t if delta_t > 0 else 0.0

            ahora_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
            writer.writerow([ahora_str, f"{watts:.3f}"])
            csv_file.flush()

            energia_wh += (watts * delta_t) / 3600.0
            muestras += 1

            print(f"\r[{ahora_str}] Power: {watts:.2f} W | "
                  f"Energia acumulada: {energia_wh:.4f} Wh | Muestras: {muestras}",
                  end="", flush=True)

            energia_prev = energia_actual
            tiempo_prev = tiempo_actual
    finally:
        csv_file.close()
        fin = datetime.now()
        duracion_seg = (fin - inicio).total_seconds()
        print("\n")
        print(f"=== Resumen de medicion ({args.etiqueta}) ===")
        print(f"Inicio:              {inicio}")
        print(f"Fin:                 {fin}")
        print(f"Duracion:            {duracion_seg:.1f} s ({duracion_seg/60:.2f} min)")
        print(f"Muestras tomadas:    {muestras}")
        print(f"Energia total:       {energia_wh:.4f} Wh")
        if duracion_seg > 0:
            print(f"Potencia promedio:   {(energia_wh*3600)/duracion_seg:.2f} W")
        print(f"CSV guardado en:     {csv_path}")
        print()
        print("Recuerda: resta el consumo baseline (standby) medido por separado")
        print("para obtener la energia neta atribuible al pipeline.")


if __name__ == "__main__":
    main()
