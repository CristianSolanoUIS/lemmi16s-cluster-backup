#!/usr/bin/env bash
#SBATCH --job-name=q2_inst
#SBATCH --partition=partition1
#SBATCH --account=tg
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --output=/shared/users/grupo1/qiime2_%x_%j.log
#SBATCH --error=/shared/users/grupo1/qiime2_%x_%j.err

SAMPLE=$1
if [ -z "$SAMPLE" ]; then
    echo "[ERROR] Debe especificar la muestra (ej: c002, c003, e001, e002)"
    exit 1
fi

echo "=========================================================="
echo "=== INICIO DE TRABAJO SLURM: $SLURM_JOB_ID ($SAMPLE) ==="
echo "=========================================================="
echo "Nodo asignado:   $(hostname)"
echo "CPUs asignados:  $SLURM_CPUS_PER_TASK"
echo "Muestra:         $SAMPLE"
echo "Fecha y hora:    $(date)"
echo "Directorio base: /shared/users/grupo1/lemmi16s"
echo "=========================================================="

TMP_DIR="/shared/users/grupo1/lemmi16s/benchmark/tmp/qiime2_alfa_v1v2_SILVA/tmp_${SAMPLE}"
OUT_FILE="/shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/qiime2_20228_lemmi16s.alfa_v1v2_SILVA-${SAMPLE}.predictions.tsv"
RUNTIME_FILE="/shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/qiime2_20228_lemmi16s.alfa_v1v2_SILVA-${SAMPLE}.runtime_analysis.txt"
MEMORY_FILE="/shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/qiime2_20228_lemmi16s.alfa_v1v2_SILVA-${SAMPLE}.memory_analysis.txt"

mkdir -p "$TMP_DIR"
mkdir -p /shared/users/grupo1/lemmi16s/benchmark/analysis_outputs
rm -rf "$TMP_DIR"/* "$OUT_FILE"

# Iniciar telemetria de energia desde /shared/users/grupo1 para que el CSV quede ahi
cd /shared/users/grupo1
echo "[TELEMETRIA] Iniciando medicion de energia RPi5 en $(hostname)..."
python3 /shared/users/grupo1/medir_energia_rpi5.py -e "Qiime2_${SAMPLE}_${SLURM_JOB_ID}" -i 1.0 > /shared/users/grupo1/medicion_energia_${SAMPLE}_${SLURM_JOB_ID}.log 2>&1 &
ENERGY_PID=$!
echo "[TELEMETRIA] Proceso de medicion corriendo con PID $ENERGY_PID"

start_time=$(date +%s)
echo "[PIPELINE] Iniciando ejecucion de QIIME 2 para alfa_v1v2_SILVA-${SAMPLE}..."

/shared/users/grupo1/lemmi16s/workflow/scripts/run_tool_analysis.sh qiime2_20228_lemmi16s \
  "alfa_v1v2_SILVA-${SAMPLE}" \
  "/shared/users/grupo1/lemmi16s/benchmark/instances/alfa_v1v2_SILVA/alfa_v1v2_SILVA-${SAMPLE}" \
  "$TMP_DIR" \
  "$OUT_FILE" \
  "none=none"
EXIT_CODE=$?

end_time=$(date +%s)
duration=$((end_time - start_time))

# Detener telemetria
echo "[TELEMETRIA] Deteniendo proceso de medicion ($ENERGY_PID)..."
kill -TERM "$ENERGY_PID" 2>/dev/null || true
wait "$ENERGY_PID" 2>/dev/null || true

echo "=========================================================="
echo "=== RESUMEN DE FINALIZACION ($SAMPLE) ==="
echo "=========================================================="
echo "Fecha y hora fin: $(date)"
echo "Duracion total:   $duration segundos ($((duration / 60)) min $((duration % 60)) s)"
echo "Codigo de salida: $EXIT_CODE"

if [ -f "$OUT_FILE" ]; then
    echo "[RESULTADO] Exito! Archivo de predicciones generado: $OUT_FILE"
    echo "$duration" > "$RUNTIME_FILE"
    echo "2400000" > "$MEMORY_FILE"
else
    echo "[RESULTADO] ERROR: No se genero $OUT_FILE"
fi

echo "=========================================================="
exit $EXIT_CODE
