#!/usr/bin/env bash
#SBATCH --job-name=qiime2_c001
#SBATCH --partition=partition1
#SBATCH --account=tg
#SBATCH --nodes=1
#SBATCH --nodelist=rbp5-1
#SBATCH --cpus-per-task=4
#SBATCH --output=/shared/users/grupo1/qiime2_test_%j.log
#SBATCH --error=/shared/users/grupo1/qiime2_test_%j.err

echo "=========================================================="
echo "=== INICIO DE TRABAJO SLURM: $SLURM_JOB_ID ==="
echo "=========================================================="
echo "Nodo asignado:   $(hostname)"
echo "CPUs asignados:  $SLURM_CPUS_PER_TASK"
echo "Fecha y hora:    $(date)"
echo "Directorio base: /shared/users/grupo1/lemmi16s"
echo "=========================================================="

# 1. Preparar directorio de trabajo
WORK_DIR="/shared/users/grupo1/lemmi16s/benchmark/tmp/test_qiime2"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
rm -rf tmp_alfa_v1v2_SILVA-c001 test_c001.predictions.tsv

# 2. Iniciar telemetria de energia en segundo plano
echo "[TELEMETRIA] Iniciando medicion de energia RPi5..."
python3 /shared/users/grupo1/medir_energia_rpi5.py -e "Qiime2_c001_${SLURM_JOB_ID}" -i 1.0 > /shared/users/grupo1/medicion_energia_${SLURM_JOB_ID}.log 2>&1 &
ENERGY_PID=$!
echo "[TELEMETRIA] Proceso de medicion corriendo con PID $ENERGY_PID"

# 3. Ejecutar pipeline QIIME 2
start_time=$(date +%s)
echo "[PIPELINE] Iniciando ejecucion de QIIME 2 para alfa_v1v2_SILVA-c001..."

/shared/users/grupo1/lemmi16s/workflow/scripts/run_tool_analysis.sh qiime2_20228_lemmi16s \
  alfa_v1v2_SILVA-c001 \
  /shared/users/grupo1/lemmi16s/benchmark/instances/alfa_v1v2_SILVA/alfa_v1v2_SILVA-c001 \
  /shared/users/grupo1/lemmi16s/benchmark/tmp/qiime2_alfa_v1v2_SILVA/tmp_alfa_v1v2_SILVA \
  /shared/users/grupo1/lemmi16s/benchmark/tmp/test_qiime2/test_c001.predictions.tsv \
  "none=none"
EXIT_CODE=$?

end_time=$(date +%s)
duration=$((end_time - start_time))

# 4. Detener telemetria de energia de forma limpia
echo "[TELEMETRIA] Finalizando medicion de energia (PID: $ENERGY_PID)..."
kill -TERM "$ENERGY_PID" 2>/dev/null || true
wait "$ENERGY_PID" 2>/dev/null || true

echo "=========================================================="
echo "=== RESUMEN DE FINALIZACION ==="
echo "=========================================================="
echo "Fecha y hora fin: $(date)"
echo "Duracion total:   $duration segundos ($((duration / 60)) min $((duration % 60)) s)"
echo "Codigo de salida: $EXIT_CODE"

if [ -f "$WORK_DIR/test_c001.predictions.tsv" ]; then
    echo "[RESULTADO] Exito! Archivo de predicciones generado:"
    ls -lh "$WORK_DIR/test_c001.predictions.tsv"
    echo "--- Primeras 5 lineas de predicciones ---"
    head -n 5 "$WORK_DIR/test_c001.predictions.tsv"
else
    echo "[RESULTADO] ATENCION: No se genero test_c001.predictions.tsv"
fi

# Mover CSV de energia a la carpeta de usuario
mv /shared/users/grupo1/lemmi16s/benchmark/tmp/test_qiime2/energia_Qiime2_c001_${SLURM_JOB_ID}_*.csv /shared/users/grupo1/ 2>/dev/null || true

echo "=========================================================="
exit $EXIT_CODE
