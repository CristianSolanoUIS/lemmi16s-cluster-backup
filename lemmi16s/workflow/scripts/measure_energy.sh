#!/usr/bin/env bash
#
# measure_energy.sh — Mide tiempo, memoria y energia (Wh) atribuida a un proceso,
#                      usando sustraccion de linea base (baseline) en reposo.
#
# Por que baseline: no existe forma de medir energia "por proceso" directamente,
# ni con hardware ni con un medidor de enchufe -- solo se mide el sistema completo.
# El metodo estandar es: medir el sistema en reposo (baseline), medir el sistema
# corriendo el proceso, y restar. Ver metodologia de la propuesta de tesis (Fase 1
# y Fase 4: medicion de consumo en stand-by como referencia).
#
# Requiere un medidor de potencia externo del que puedas leer energia
# acumulada en Wh (o kWh) en cualquier momento.
#
# ------------------------------------------------------------------------------
# MODO 1 — Capturar linea base (reposo). Correr esto ANTES, con todo cerrado
# excepto lo minimo necesario (WSL2 sin el pipeline corriendo).
#
#   ./measure_energy.sh baseline <duracion_segundos>
#
# Ejemplo (mide 5 minutos de reposo):
#   ./measure_energy.sh baseline 300
#
# ------------------------------------------------------------------------------
# MODO 2 — Medir el proceso, restando la linea base automaticamente.
#
#   ./measure_energy.sh run "<comando>" [total_reads]
#
# Ejemplo:
#   ./measure_energy.sh run "lemmi16s --cores 6" 10000
#
# ------------------------------------------------------------------------------

set -e

BASELINE_FILE="energy_baseline.txt"
MODE="$1"

# ------------------------------------------------------------------------------
# MODO: baseline
# ------------------------------------------------------------------------------
if [ "$MODE" == "baseline" ]; then
  DURATION="$2"
  if [ -z "$DURATION" ]; then
    echo "Uso: $0 baseline <duracion_segundos>"
    exit 1
  fi

  echo "=========================================="
  echo " Captura de linea base (reposo)"
  echo "=========================================="
  echo "Cierra todo lo que puedas (navegador, otras apps) antes de continuar."
  echo "El sistema debe quedar lo mas ocioso posible durante ${DURATION}s."
  echo ""
  read -p "Lectura INICIAL del medidor (Wh): " WH_INICIO

  echo "Esperando ${DURATION}s en reposo..."
  sleep "$DURATION"

  echo ""
  read -p "Lectura FINAL del medidor (Wh): " WH_FIN

  ENERGY_WH=$(echo "$WH_FIN - $WH_INICIO" | bc)
  DURATION_HOURS=$(echo "$DURATION / 3600" | bc -l)
  BASELINE_POWER_W=$(echo "$ENERGY_WH / $DURATION_HOURS" | bc -l)

  echo "$BASELINE_POWER_W" > "$BASELINE_FILE"

  echo "=========================================="
  echo "Linea base guardada: $(printf '%.3f' $BASELINE_POWER_W) W"
  echo "Archivo: $BASELINE_FILE"
  echo "=========================================="
  echo ""
  echo "Ahora corre: $0 run \"<comando>\" [total_reads]"
  exit 0
fi

# ------------------------------------------------------------------------------
# MODO: run
# ------------------------------------------------------------------------------
if [ "$MODE" == "run" ]; then
  CMD="$2"
  TOTAL_READS="$3"

  if [ -z "$CMD" ]; then
    echo "Uso: $0 run \"<comando>\" [total_reads]"
    exit 1
  fi

  if [ ! -f "$BASELINE_FILE" ]; then
    echo "AVISO: no hay linea base guardada ($BASELINE_FILE no existe)."
    echo "Corre primero: $0 baseline <duracion_segundos>"
    exit 1
  fi
  BASELINE_POWER_W=$(cat "$BASELINE_FILE")

  LOGFILE="energy_log_$(date +%Y%m%d_%H%M%S).txt"

  echo "=========================================="
  echo " Medicion de proceso — $(date)"
  echo " Comando: $CMD"
  echo " Linea base cargada: $(printf '%.3f' $BASELINE_POWER_W) W"
  echo "=========================================="
  echo ""
  read -p "Lectura INICIAL del medidor (Wh): " WH_INICIO

  echo ""
  echo "Ejecutando comando..."
  echo "--------------------------------------------"

  START=$(date +%s.%N)
  /usr/bin/time -v bash -c "$CMD" 2> "$LOGFILE.raw" || {
    echo "AVISO: el comando termino con error. Revisa $LOGFILE.raw"
  }
  END=$(date +%s.%N)
  RUNTIME=$(echo "$END - $START" | bc)

  echo "--------------------------------------------"
  echo "Proceso terminado. Runtime: ${RUNTIME}s"
  echo ""
  read -p "Lectura FINAL del medidor (Wh): " WH_FIN

  TOTAL_ENERGY_WH=$(echo "$WH_FIN - $WH_INICIO" | bc)
  RUNTIME_HOURS=$(echo "$RUNTIME / 3600" | bc -l)
  TOTAL_AVG_POWER_W=$(echo "$TOTAL_ENERGY_WH / $RUNTIME_HOURS" | bc -l)

  # Energia atribuida al proceso = energia total - (potencia base * tiempo)
  BASELINE_ENERGY_WH=$(echo "$BASELINE_POWER_W * $RUNTIME_HOURS" | bc -l)
  PROCESS_ENERGY_WH=$(echo "$TOTAL_ENERGY_WH - $BASELINE_ENERGY_WH" | bc -l)
  PROCESS_AVG_POWER_W=$(echo "$PROCESS_ENERGY_WH / $RUNTIME_HOURS" | bc -l)

  MEM_PEAK_KB=$(grep "Maximum resident set size" "$LOGFILE.raw" | awk -F': ' '{print $2}')
  MEM_PEAK_GB=$(echo "$MEM_PEAK_KB / 1048576" | bc -l)

  {
    echo "=========================================="
    echo " Resultados — $(date)"
    echo "=========================================="
    echo "Comando:                  $CMD"
    echo "Runtime:                   ${RUNTIME} s  ($(printf '%.4f' $RUNTIME_HOURS) h)"
    echo "Memoria pico:               ${MEM_PEAK_KB} KB  ($(printf '%.2f' $MEM_PEAK_GB) GB)"
    echo ""
    echo "-- Medicion cruda (sistema completo) --"
    echo "Energia total medida:       ${TOTAL_ENERGY_WH} Wh"
    echo "Potencia media (sistema):   $(printf '%.2f' $TOTAL_AVG_POWER_W) W"
    echo ""
    echo "-- Linea base (reposo) --"
    echo "Potencia base:              $(printf '%.3f' $BASELINE_POWER_W) W"
    echo "Energia base en este lapso: $(printf '%.4f' $BASELINE_ENERGY_WH) Wh"
    echo ""
    echo "-- Atribuida al proceso (total - base) --"
    echo "Energia del proceso:        $(printf '%.4f' $PROCESS_ENERGY_WH) Wh"
    echo "Potencia media del proceso: $(printf '%.2f' $PROCESS_AVG_POWER_W) W"

    if [ -n "$TOTAL_READS" ]; then
      READS_PER_WH=$(echo "$TOTAL_READS / $PROCESS_ENERGY_WH" | bc -l)
      echo ""
      echo "Total reads:                ${TOTAL_READS}"
      echo "Eficiencia (reads/Wh):      $(printf '%.2f' $READS_PER_WH)"
    fi
    echo "=========================================="
  } | tee "$LOGFILE"

  echo ""
  echo "Log completo: $LOGFILE"
  echo "Salida cruda de /usr/bin/time: $LOGFILE.raw"
  exit 0
fi

echo "Uso:"
echo "  $0 baseline <duracion_segundos>     # capturar linea base en reposo"
echo "  $0 run \"<comando>\" [total_reads]    # medir proceso, restando linea base"
exit 1
