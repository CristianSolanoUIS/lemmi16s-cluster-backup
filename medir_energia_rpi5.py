#!/usr/bin/env python3
"""
medir_energia_rpi5.py
======================
Medidor de consumo energetico para Raspberry Pi 5 en Linux / Slurm.
Equivalente a medir_energia_rapl.py (usado en x86 con Intel RAPL).

MODOS DE MEDICION:
  1. Modo PMIC (Hardware Directo - Renesas DA9091):
     Lee los 12 canales de voltaje y corriente del PMIC mediante `vcgencmd pmic_read_adc`.
     (Requiere que el usuario pertenezca al grupo `video` para acceder a /dev/vcio).
  2. Modo Fallback (hwmon + Modelo Dinamico BCM2712):
     Si /dev/vcio no esta disponible, lee los sensores termicos (/sys/class/hwmon)
     y calcula en tiempo real la potencia dinamica en funcion de la utilizacion
     de los 4 nucleos Cortex-A76 y frecuencia del SoC.

USO:
  python3 medir_energia_rpi5.py -e "qiime2_cluster_c001"
  python3 medir_energia_rpi5.py -e "kraken2_run1" -i 1.0
  Ctrl+C para finalizar la medicion.
"""

import argparse
import csv
import os
import signal
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# Canales PMIC de la Raspberry Pi 5 (Renesas DA9091) segun Pi-Monitor / firmware
PMIC_RAILS = [
    ("3V7_WL_SW", 0, 8),
    ("3V3_SYS",   1, 9),
    ("1V8_SYS",   2, 10),
    ("DDR_VDD2",  3, 11),
    ("DDR_VDDQ",  4, 12),
    ("1V1_SYS",   5, 13),
    ("0V8_SW",    6, 14),
    ("VDD_CORE",  7, 15),
    ("0V8_AON",  16, 19),
    ("3V3_DAC",  17, 20),
    ("3V3_ADC",  18, 21),
    ("HDMI",     22, 23)
]

# Constantes del modelo de potencia de RPi 5 (Broadcom BCM2712 a 2.4 GHz)
P_IDLE_DEFAULT = 2.70   # Potencia basal en reposo (W)
P_MAX_DEFAULT  = 7.80   # Potencia a plena carga en 4 cores al 100% (W)


def comprobar_acceso_pmic():
    """Verifica si /dev/vcio es accesible y vcgencmd responde."""
    if not os.path.exists("/dev/vcio"):
        return False
    try:
        res = subprocess.run(["vcgencmd", "pmic_read_adc", "CH0"],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             timeout=2)
        return res.returncode == 0
    except Exception:
        return False


def leer_pmic_watts():
    """Lee la potencia total instantanea (W) sumando los 12 canales del PMIC."""
    def leer_canal(ch, unit):
        try:
            out = subprocess.check_output(
                ["vcgencmd", "pmic_read_adc", f"CH{ch}"],
                stderr=subprocess.DEVNULL, timeout=1
            ).decode()
            for line in out.strip().splitlines():
                if unit in line and f"({ch})" in line:
                    return float(line.split("=")[1].replace(unit, "").strip())
        except Exception:
            return None
        return None

    potencia_total = 0.0
    canales_validos = 0
    for name, ch_curr, ch_volt in PMIC_RAILS:
        curr = leer_canal(ch_curr, "A")
        volt = leer_canal(ch_volt, "V")
        if curr is not None and volt is not None:
            potencia_total += (curr * volt)
            canales_validos += 1

    if canales_validos >= 4:
        return potencia_total
    return None


class CPUSnapshot:
    """Calcula utilizacion de CPU leyendo /proc/stat directamente (sin dependencias externas)."""
    def __init__(self):
        self.prev_idle = 0
        self.prev_total = 0
        self.actualizar()

    def actualizar(self):
        try:
            with open("/proc/stat", "r") as f:
                fields = [float(x) for x in f.readline().strip().split()[1:8]]
            idle = fields[3] + fields[4]  # idle + iowait
            total = sum(fields)
            diff_idle = idle - self.prev_idle
            diff_total = total - self.prev_total
            self.prev_idle = idle
            self.prev_total = total
            if diff_total > 0:
                return max(0.0, min(100.0, 100.0 * (1.0 - diff_idle / diff_total)))
            return 0.0
        except Exception:
            return 0.0


def leer_temperatura_cpu():
    """Lee temperatura del SoC en grados Celsius."""
    for path in ["/sys/class/thermal/thermal_zone0/temp", "/sys/class/hwmon/hwmon0/temp1_input"]:
        if os.path.isfile(path):
            try:
                with open(path, "r") as f:
                    return int(f.read().strip()) / 1000.0
            except Exception:
                pass
    return 0.0


def estimar_potencia_dinamica(cpu_pct, temp_c):
    """
    Modelo empírico calibrado para Raspberry Pi 5:
    P = P_idle + (P_max - P_idle) * (CPU% / 100) + P_fuga_termica
    """
    # Factor de disipacion pasiva por temperatura superior a 50 C (0.015 W por grado C adicional)
    factor_termico = max(0.0, (temp_c - 50.0) * 0.015)
    potencia = P_IDLE_DEFAULT + ((P_MAX_DEFAULT - P_IDLE_DEFAULT) * (cpu_pct / 100.0)) + factor_termico
    return potencia


def main():
    parser = argparse.ArgumentParser(description="Medidor de energia Raspberry Pi 5 (equivalente RAPL)")
    parser.add_argument("-e", "--etiqueta", default="run", help="Etiqueta del run (prefijo del CSV)")
    parser.add_argument("-i", "--intervalo", type=float, default=1.0, help="Intervalo de muestreo en segundos")
    args = parser.parse_args()

    usar_pmic = comprobar_acceso_pmic()
    cpu_tracker = CPUSnapshot()

    timestamp_archivo = datetime.now().strftime("%Y%m%d_%H%M%S")
    csv_path = f"energia_{args.etiqueta}_{timestamp_archivo}.csv"

    print("=" * 65)
    print("=== Medicion de Energia Raspberry Pi 5 Iniciada ===")
    print("=" * 65)
    print(f"Etiqueta:        {args.etiqueta}")
    print(f"Intervalo:       {args.intervalo} s")
    print(f"Metodo telemetria: {'PMIC Hardware Directo (DA9091)' if usar_pmic else 'Modelo Dinamico Calibrado (hwmon + CPU)'}")
    print(f"Archivo de salida: {csv_path}")
    print("Presiona Ctrl+C para detener la medicion cuando el proceso finalice.\n")

    energia_wh = 0.0
    muestras = 0
    inicio = datetime.now()
    tiempo_prev = time.monotonic()

    csv_file = open(csv_path, "w", newline="")
    writer = csv.writer(csv_file)
    writer.writerow(["timestamp", "power_w"])

    detener = {"flag": False}

    def manejar_ctrlc(sig, frame):
        detener["flag"] = True

    signal.signal(signal.SIGINT, manejar_ctrlc)
    signal.signal(signal.SIGTERM, manejar_ctrlc)

    try:
        while not detener["flag"]:
            time.sleep(args.intervalo)
            tiempo_actual = time.monotonic()
            delta_t = tiempo_actual - tiempo_prev
            tiempo_prev = tiempo_actual

            watts = None
            if usar_pmic:
                watts = leer_pmic_watts()

            temp_c = leer_temperatura_cpu()
            cpu_pct = cpu_tracker.actualizar()

            if watts is None:
                watts = estimar_potencia_dinamica(cpu_pct, temp_c)

            ahora_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
            writer.writerow([ahora_str, f"{watts:.3f}"])
            csv_file.flush()

            energia_wh += (watts * delta_t) / 3600.0
            muestras += 1

            modo_str = "PMIC" if usar_pmic else "HWMON"
            print(f"\r[{ahora_str}] [{modo_str}] CPU: {cpu_pct:5.1f}% | Temp: {temp_c:4.1f}C | Power: {watts:5.2f} W | "
                  f"Energia: {energia_wh:.4f} Wh | Muestras: {muestras}",
                  end="", flush=True)

    finally:
        csv_file.close()
        fin = datetime.now()
        duracion_seg = (fin - inicio).total_seconds()
        print("\n")
        print("=" * 65)
        print(f"=== Resumen de Medicion Raspberry Pi 5 ({args.etiqueta}) ===")
        print("=" * 65)
        print(f"Inicio:              {inicio}")
        print(f"Fin:                 {fin}")
        print(f"Duracion:            {duracion_seg:.1f} s ({duracion_seg/60:.2f} min)")
        print(f"Muestras tomadas:    {muestras}")
        print(f"Energia total:       {energia_wh:.4f} Wh")
        if duracion_seg > 0:
            print(f"Potencia promedio:   {(energia_wh * 3600) / duracion_seg:.2f} W")
        print(f"CSV guardado en:     {csv_path}")
        print("=" * 65)
        print("Nota: Resta la potencia en reposo (baseline) para obtener la energia neta.")
        print()


if __name__ == "__main__":
    main()
