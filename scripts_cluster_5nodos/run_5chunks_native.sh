#!/usr/bin/env bash
# ==============================================================================
# run_5chunks_native.sh
# Ejecutor nativo (PC / Laptop sin Docker) para correr y validar los 3 pipelines
# divididos en 5 chunks paralelos simulando los 5 nodos del clúster.
# ==============================================================================

set -e

PIPELINE=$1
INSTANCE_SAMPLE=$2
BASE_DIR="${3:-/home/cristian-solano/lemmi16s}"

if [ -z "$PIPELINE" ] || [ -z "$INSTANCE_SAMPLE" ]; then
    echo "Uso: $0 <kraken2|lotus3|qiime2> <INSTANCE-SAMPLE> [BASE_DIR]"
    echo "Ejemplo: $0 kraken2 HOMD_v4_GTDB-c001"
    echo "Ejemplo: $0 lotus3 HM_Contaminated_Soil-c001"
    echo "Ejemplo: $0 qiime2 alfa_v1v2_SILVA-c001"
    exit 1
fi

INSTANCE=$(echo "$INSTANCE_SAMPLE" | cut -d'-' -f1)
SAMPLE=$(echo "$INSTANCE_SAMPLE" | cut -d'-' -f2)

INSTANCE_DIR="${BASE_DIR}/benchmark/instances/${INSTANCE}/${INSTANCE_SAMPLE}"
TMP_SPLIT_DIR="${BASE_DIR}/benchmark/tmp/split5_native_${INSTANCE_SAMPLE}"
OUT_DIR="${BASE_DIR}/benchmark/analysis_outputs"
PRED_FINAL="${OUT_DIR}/${PIPELINE}_lemmi16s.${INSTANCE_SAMPLE}.5chunks_merged.tsv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Rutas a los entornos nativos en ~/proyectos
KRAKEN2_BIN_DIR="/home/cristian-solano/proyectos/miniconda3/envs/kraken2_env/bin"
LOTUS3_BIN_DIR="/home/cristian-solano/proyectos/lotus3"
QIIME2_BIN_DIR="/home/cristian-solano/proyectos/miniconda3/envs/qiime2_env/bin"

echo "=========================================================="
echo "=== EJECUCION NATIVA EN 5 CHUNKS (LOCAL PC / SIN DOCKER) ==="
echo "Pipeline:        $PIPELINE"
echo "Muestra:         $INSTANCE_SAMPLE"
echo "Datos origen:    $INSTANCE_DIR"
echo "Directorio temp: $TMP_SPLIT_DIR"
echo "Salida final:    $PRED_FINAL"
echo "=========================================================="

if [ ! -d "$INSTANCE_DIR" ]; then
    echo "[ERROR] No existe el directorio de instancia: $INSTANCE_DIR"
    exit 1
fi

# 1. Particion en 5
echo "[PASO 1] Dividiendo lecturas en 5 chunks balanceados..."
python3 "${SCRIPT_DIR}/split_query_reads_5.py" \
  -i "$INSTANCE_DIR" \
  -o "$TMP_SPLIT_DIR" \
  -n 5

# 2. Ejecucion de los 5 chunks en paralelo
echo "[PASO 2] Ejecutando los 5 chunks en paralelo (nativo)..."
PIDS=()

for i in {1..5}; do
    CHUNK_DIR="${TMP_SPLIT_DIR}/chunk_${i}"
    CHUNK_OUT="${TMP_SPLIT_DIR}/chunk_${i}.predictions.tsv"
    CHUNK_TMP="${TMP_SPLIT_DIR}/tmp_work_${i}"
    mkdir -p "$CHUNK_TMP"

    (
        echo "  [+] Iniciando Chunk ${i} en segundo plano..."
        t_start=$(date +%s)
        cd "${CHUNK_TMP}"

        if [ "$PIPELINE" == "kraken2" ]; then
            DB_DIR="${BASE_DIR}/benchmark/tmp/kraken2_16s_HOMD_v4_GTDB/tmp_HOMD_v4_GTDB/database"
            
            "${KRAKEN2_BIN_DIR}/kraken2" --threads 2 --db "${DB_DIR}" \
              --output query.out --report query.report --paired "${CHUNK_DIR}/queryReads1.fq" "${CHUNK_DIR}/queryReads2.fq" > "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            "${KRAKEN2_BIN_DIR}/bracken" -d "${DB_DIR}" \
              -i query.report -o query.bracken -l 'G' -r 150 >> "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            EDIT_SCRIPT="${BASE_DIR}/resources/candidate_containers/kraken_213_lemmi16s/scripts/editResult.py"
            [ ! -f "$EDIT_SCRIPT" ] && EDIT_SCRIPT="${SCRIPT_DIR}/../lemmi16s/resources/candidate_containers/kraken_213_lemmi16s/scripts/editResult.py"
            python3 "$EDIT_SCRIPT" \
              query_bracken_genuses.report results.tsv summary_taxonomy.tsv >> "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            cp results.tsv "${CHUNK_OUT}"

        elif [ "$PIPELINE" == "lotus3" ]; then
            DB_PATH="${BASE_DIR}/benchmark/tmp/lotus303_16s_HM_Contaminated/tmp_HM_Contaminated_Soil/database"
            mkdir -p reads
            cp "${CHUNK_DIR}/queryReads1.fq" reads/.
            cp "${CHUNK_DIR}/queryReads2.fq" reads/.
            echo -e "#SampleID\tfastqFile\tSequencingRun\nSample1\tqueryReads1.fq,queryReads2.fq\tRun1" > reads/miSeqMap.sm.txt

            "${LOTUS3_BIN_DIR}/lotus3" -derepMin 1:1,1:2,1:3 -i reads/ -m reads/miSeqMap.sm.txt -o reads-output/ \
              -refDB "${DB_PATH}/reference.fasta" -tax4refDB "${DB_PATH}/reference.tsv" -buildPhylo 0 -lulu 0 -t 2 > "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            "${KRAKEN2_BIN_DIR}/biom" convert -i reads-output/OTU.biom -o results.txt --to-tsv --header-key taxonomy >> "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            EDIT_SCRIPT="${BASE_DIR}/resources/candidate_containers/lotus_303_lemmi16s/scripts/editResult.py"
            [ ! -f "$EDIT_SCRIPT" ] && EDIT_SCRIPT="${SCRIPT_DIR}/../lemmi16s/resources/candidate_containers/lotus_303_lemmi16s/scripts/editResult.py"
            python3 "$EDIT_SCRIPT" \
              results.txt results.tsv summary_taxonomy.tsv >> "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            cp results.tsv "${CHUNK_OUT}"

        elif [ "$PIPELINE" == "qiime2" ]; then
            MODEL_PATH="${BASE_DIR}/benchmark/tmp/qiime2_alfa_v1v2_SILVA/tmp_alfa_v1v2_SILVA"
            export PATH="${QIIME2_BIN_DIR}:$PATH"

            echo "sample-id,absolute-filepath,direction" > manifest.tsv
            echo -e "sample-chunk,${CHUNK_DIR}/queryReads1.fq,forward" >> manifest.tsv
            echo -e "sample-chunk,${CHUNK_DIR}/queryReads2.fq,reverse" >> manifest.tsv

            qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' \
              --input-path manifest.tsv --output-path demux.qza --input-format PairedEndFastqManifestPhred33 > "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            qiime quality-filter q-score --i-demux demux.qza --p-min-quality 20 \
              --o-filtered-sequences demux-filtered.qza --o-filter-stats demux-filter-stats.qza >> "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            qiime deblur denoise-16S --i-demultiplexed-seqs demux-filtered.qza --p-trim-length 120 --p-jobs-to-start 2 \
              --o-representative-sequences rep-seqs.qza --o-table table.qza --p-sample-stats --o-stats deblur-stats.qza >> "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            qiime feature-classifier classify-sklearn --i-classifier "${MODEL_PATH}/referenceClassificator.qza" \
              --i-reads rep-seqs.qza --p-n-jobs 2 --o-classification taxonomy.qza >> "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            qiime taxa collapse --i-table table.qza --i-taxonomy taxonomy.qza --p-level 7 \
              --o-collapsed-table phyla-table.qza >> "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            qiime tools export --input-path phyla-table.qza --output-path . >> "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            biom convert -i feature-table.biom -o results.txt --to-tsv >> "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            EDIT_SCRIPT="${BASE_DIR}/resources/candidate_containers/qiime2_20228_lemmi16s/scripts/editResult.py"
            [ ! -f "$EDIT_SCRIPT" ] && EDIT_SCRIPT="${SCRIPT_DIR}/../lemmi16s/resources/candidate_containers/qiime2_20228_lemmi16s/scripts/editResult.py"
            python3 "$EDIT_SCRIPT" \
              results.txt results.tsv summary_taxonomy.tsv >> "${CHUNK_TMP}/chunk_${i}.log" 2>&1
            
            cp results.tsv "${CHUNK_OUT}"
        fi

        t_end=$(date +%s)
        echo "  [OK] Chunk ${i} finalizó en $((t_end - t_start)) segundos."
    ) &
    PIDS+=($!)
done

# Esperar que los 5 procesos paralelos terminen
echo "Esperando finalizacion de los 5 chunks..."
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

# Verificar que todos los outputs existan
for i in {1..5}; do
    CHUNK_OUT="${TMP_SPLIT_DIR}/chunk_${i}.predictions.tsv"
    if [ ! -f "$CHUNK_OUT" ]; then
        echo "[ERROR] El chunk ${i} no genero el archivo de predicciones: ${CHUNK_OUT}"
        echo "Revisar log en ${TMP_SPLIT_DIR}/tmp_work_${i}/chunk_${i}.log"
        exit 1
    fi
done

# 3. Fusionar predicciones
echo "[PASO 3] Fusionando las predicciones de los 5 chunks con merge_predictions_5.py..."
mkdir -p "$OUT_DIR"
python3 "${SCRIPT_DIR}/merge_predictions_5.py" \
  -i \
  "${TMP_SPLIT_DIR}/chunk_1.predictions.tsv" \
  "${TMP_SPLIT_DIR}/chunk_2.predictions.tsv" \
  "${TMP_SPLIT_DIR}/chunk_3.predictions.tsv" \
  "${TMP_SPLIT_DIR}/chunk_4.predictions.tsv" \
  "${TMP_SPLIT_DIR}/chunk_5.predictions.tsv" \
  -o "$PRED_FINAL"

echo "=========================================================="
echo "=== EJECUCION NATIVA COMPLETADA EXITOSAMENTE ==="
echo "Predicciones fusionadas disponibles en:"
echo "  $PRED_FINAL"
echo "Primeras 15 lineas del resultado:"
head -n 15 "$PRED_FINAL"
echo "=========================================================="
