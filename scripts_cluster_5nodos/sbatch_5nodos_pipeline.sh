#!/usr/bin/env bash
# ==============================================================================
# sbatch_5nodos_pipeline.sh
# Ejecutor distribuido en 5 nodos de Slurm para LEMMI16s
#
# Flujo:
# 1. Divide los queryReads de la muestra en 5 chunks balanceados (1 por nodo).
# 2. Lanza un Slurm Job Array (array 1-5) distribuyendo 1 chunk a cada nodo de partition1.
# 3. Cada nodo ejecuta el pipeline de inicio a fin sobre su 20% de lecturas.
# 4. Al completar las 5 tareas, fusiona las 5 predicciones sumando la columna 'Size'.
# ==============================================================================

set -e

PIPELINE=$1
INSTANCE_SAMPLE=$2
BASE_DIR="${3:-/shared/users/grupo1/lemmi16s}"

if [ -z "$PIPELINE" ] || [ -z "$INSTANCE_SAMPLE" ]; then
    echo "Uso: $0 <kraken2|lotus3|qiime2> <INSTANCE-SAMPLE> [BASE_DIR]"
    echo "Ejemplo: $0 qiime2 alfa_v1v2_SILVA-c001"
    exit 1
fi

INSTANCE=$(echo "$INSTANCE_SAMPLE" | cut -d'-' -f1)
SAMPLE=$(echo "$INSTANCE_SAMPLE" | cut -d'-' -f2)

INSTANCE_DIR="${BASE_DIR}/benchmark/instances/${INSTANCE}/${INSTANCE_SAMPLE}"
TMP_SPLIT_DIR="${BASE_DIR}/benchmark/tmp/split5_${INSTANCE_SAMPLE}"
OUT_DIR="${BASE_DIR}/benchmark/analysis_outputs"
PRED_FINAL="${OUT_DIR}/${PIPELINE}_lemmi16s.${INSTANCE_SAMPLE}.predictions.tsv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo "=== EJECUCION DISTRIBUIDA EN 5 NODOS (SLURM) ==="
echo "Pipeline:        $PIPELINE"
echo "Muestra:         $INSTANCE_SAMPLE"
echo "Datos origen:    $INSTANCE_DIR"
echo "Directorio temp: $TMP_SPLIT_DIR"
echo "Salida final:    $PRED_FINAL"
echo "=========================================================="

# 1. Particion de lecturas en 5 pedazos
echo "[PASO 1] Dividiendo lecturas en 5 chunks balanceados..."
python3 "${SCRIPT_DIR}/split_query_reads_5.py" \
  -i "$INSTANCE_DIR" \
  -o "$TMP_SPLIT_DIR" \
  -n 5

# 2. Generar script Slurm para el Job Array de los 5 nodos
ARRAY_SCRIPT="${TMP_SPLIT_DIR}/slurm_array_worker.sh"

cat << 'EOF' > "$ARRAY_SCRIPT"
#!/usr/bin/env bash
#SBATCH --job-name=lemmi_5n
#SBATCH --partition=partition1
#SBATCH --account=tg
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --output=/shared/users/grupo1/logs_slurm/5nodos_%x_%A_%a.log
#SBATCH --error=/shared/users/grupo1/logs_slurm/5nodos_%x_%A_%a.err

set -e

CHUNK_ID=$SLURM_ARRAY_TASK_ID
CHUNK_DIR="${TMP_SPLIT_DIR}/chunk_${CHUNK_ID}"
CHUNK_OUT="${TMP_SPLIT_DIR}/chunk_${CHUNK_ID}.predictions.tsv"
CHUNK_TMP="${TMP_SPLIT_DIR}/tmp_work_${CHUNK_ID}"

mkdir -p "$CHUNK_TMP"
echo "=== NODO $(hostname) INICIANDO CHUNK $CHUNK_ID ==="
echo "Hora inicio: $(date)"

if [ "$PIPELINE" == "kraken2" ]; then
    MODEL_PATH="${BASE_DIR}/benchmark/repository/GTDB"
    /shared/users/grupo1/lemmi16s/workflow/scripts/run_tool_analysis.sh kraken_213_lemmi16s \
      "chunk_${CHUNK_ID}" "$CHUNK_DIR" "$MODEL_PATH" "$CHUNK_OUT" "none=none"

elif [ "$PIPELINE" == "lotus3" ]; then
    MODEL_PATH="${BASE_DIR}/benchmark/repository/SILVA"
    /shared/users/grupo1/lemmi16s/workflow/scripts/run_tool_analysis.sh lotus_303_lemmi16s \
      "chunk_${CHUNK_ID}" "$CHUNK_DIR" "$MODEL_PATH" "$CHUNK_OUT" "none=none"

elif [ "$PIPELINE" == "qiime2" ]; then
    MODEL_PATH="${BASE_DIR}/benchmark/tmp/qiime2_alfa_v1v2_SILVA/tmp_alfa_v1v2_SILVA"
    /shared/users/grupo1/lemmi16s/workflow/scripts/run_tool_analysis.sh qiime2_20228_lemmi16s \
      "chunk_${CHUNK_ID}" "$CHUNK_DIR" "$MODEL_PATH" "$CHUNK_OUT" "none=none"
fi

echo "=== NODO $(hostname) FINALIZO CHUNK $CHUNK_ID CON EXITO ==="
echo "Hora fin: $(date)"
EOF

# 3. Lanzar el Slurm Job Array (array=1-5) con dependency para la combinacion
echo "[PASO 2] Enviando Job Array de 5 tareas a partition1 en Slurm..."
JOB_ID=$(sbatch --parsable \
  --array=1-5 \
  --export=ALL,PIPELINE="$PIPELINE",TMP_SPLIT_DIR="$TMP_SPLIT_DIR",BASE_DIR="$BASE_DIR" \
  "$ARRAY_SCRIPT")

echo "[+] Slurm Job Array enviado con ID: $JOB_ID"
echo "[+] Monitoreando estado de los 5 nodos en paralelo..."

# Esperar a que el Job Array termine
while true; do
    REMAINING=$(squeue -h -j "$JOB_ID" | wc -l)
    if [ "$REMAINING" -eq 0 ]; then
        break
    fi
    sleep 5
done

echo "[+] Las 5 tareas de los nodos finalizaron."

# 4. Fusion y agregacion de las 5 predicciones
echo "[PASO 3] Fusionando las 5 predicciones parciales..."
PART_FILES=()
for i in {1..5}; do
    PART_FILES+=("${TMP_SPLIT_DIR}/chunk_${i}.predictions.tsv")
done

python3 "${SCRIPT_DIR}/merge_predictions_5.py" \
  -i "${PART_FILES[@]}" \
  -o "$PRED_FINAL"

echo "=========================================================="
echo "[EXITO TOTAL] Muestra $INSTANCE_SAMPLE completada!"
echo "Archivo final: $PRED_FINAL"
ls -lh "$PRED_FINAL"
echo "=========================================================="
