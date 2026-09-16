#!/usr/bin/env bash
# ==============================================================================
# run_5chunks_local.sh
# Ejecutor local (PC / Laptop) para simular y verificar la partición en 5 nodos.
# ==============================================================================

set -e

PIPELINE=$1
INSTANCE_SAMPLE=$2
BASE_DIR="${3:-/home/cristian-solano/lemmi16s}"

if [ -z "$PIPELINE" ] || [ -z "$INSTANCE_SAMPLE" ]; then
    echo "Uso: $0 <kraken2|lotus3|qiime2> <INSTANCE-SAMPLE> [BASE_DIR]"
    echo "Ejemplo: $0 kraken2 HOMD_v4_GTDB-c001"
    exit 1
fi

INSTANCE=$(echo "$INSTANCE_SAMPLE" | cut -d'-' -f1)
SAMPLE=$(echo "$INSTANCE_SAMPLE" | cut -d'-' -f2)

INSTANCE_DIR="${BASE_DIR}/benchmark/instances/${INSTANCE}/${INSTANCE_SAMPLE}"
TMP_SPLIT_DIR="${BASE_DIR}/benchmark/tmp/split5_local_${INSTANCE_SAMPLE}"
OUT_DIR="${BASE_DIR}/benchmark/analysis_outputs"
PRED_FINAL="${OUT_DIR}/${PIPELINE}_lemmi16s.${INSTANCE_SAMPLE}.5chunks_merged.tsv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo "=== EJECUCION SIMULADA EN 5 CHUNKS (LOCAL PC) ==="
echo "Pipeline:        $PIPELINE"
echo "Muestra:         $INSTANCE_SAMPLE"
echo "Datos origen:    $INSTANCE_DIR"
echo "Directorio temp: $TMP_SPLIT_DIR"
echo "Salida final:    $PRED_FINAL"
echo "=========================================================="

# 1. Particion en 5
echo "[PASO 1] Dividiendo lecturas en 5 chunks balanceados..."
python3 "${SCRIPT_DIR}/split_query_reads_5.py" \
  -i "$INSTANCE_DIR" \
  -o "$TMP_SPLIT_DIR" \
  -n 5

# 2. Ejecucion de los 5 chunks en paralelo
echo "[PASO 2] Ejecutando los 5 chunks en paralelo..."
PIDS=()

for i in {1..5}; do
    CHUNK_DIR="${TMP_SPLIT_DIR}/chunk_${i}"
    CHUNK_OUT="${TMP_SPLIT_DIR}/chunk_${i}.predictions.tsv"
    CHUNK_TMP="${TMP_SPLIT_DIR}/tmp_work_${i}"
    mkdir -p "$CHUNK_TMP"

    (
        echo "  [+] Iniciando Chunk ${i}..."
        t_start=$(date +%s)

        if [ "$PIPELINE" == "kraken2" ]; then
            DB_DIR="${BASE_DIR}/benchmark/tmp/kraken2_16s_HOMD_v4_GTDB/tmp_HOMD_v4_GTDB/database"
            docker run --rm \
              -v /home/cristian-solano:/home/cristian-solano \
              -w "${CHUNK_TMP}" \
              quay.io/ezlab/kraken_213_lemmi16s:v1.0.0_cv1 \
              /bin/bash -c "
                kraken2 --threads 2 --db ${DB_DIR} \
                  --output query.out --report query.report --paired ${CHUNK_DIR}/queryReads1.fq ${CHUNK_DIR}/queryReads2.fq
                /bracken2/bracken -d ${DB_DIR} \
                  -i query.report -o query.bracken -l 'G' -r 150
                python /data/resources/candidate_containers/kraken_213_lemmi16s/scripts/editResult.py query_bracken_genuses.report results.tsv summary_taxonomy.tsv 2>/dev/null || \
                python3 /home/cristian-solano/lemmi16s/resources/candidate_containers/kraken_213_lemmi16s/scripts/editResult.py query_bracken_genuses.report results.tsv summary_taxonomy.tsv
                cp results.tsv ${CHUNK_OUT}
              " > "${CHUNK_TMP}/chunk_${i}.log" 2>&1

        elif [ "$PIPELINE" == "lotus3" ]; then
            DB_PATH="${BASE_DIR}/benchmark/tmp/lotus303_16s_HM_Contaminated/tmp_HM_Contaminated_Soil/database"
            docker run --rm \
              -v /home/cristian-solano:/home/cristian-solano \
              -w "${CHUNK_TMP}" \
              quay.io/ezlab/lotus_303_lemmi16s:v2.0.0_cv1 \
              /bin/bash -c "
                mkdir -p reads
                cp ${CHUNK_DIR}/queryReads1.fq reads/.
                cp ${CHUNK_DIR}/queryReads2.fq reads/.
                echo -e '#SampleID\tfastqFile\tSequencingRun\nSample1\tqueryReads1.fq,queryReads2.fq\tRun1' > reads/miSeqMap.sm.txt
                lotus3 -derepMin 1:1,1:2,1:3 -i reads/ -m reads/miSeqMap.sm.txt -o reads-output/ \
                  -refDB ${DB_PATH}/reference.fasta -tax4refDB ${DB_PATH}/reference.tsv -t 2
                biom convert -i reads-output/OTU.biom -o results.txt --to-tsv --header-key taxonomy
                python3 /home/cristian-solano/lemmi16s-cluster-backup/lemmi16s/resources/candidate_containers/lotus_303_lemmi16s/scripts/editResult.py results.txt results.tsv summary_taxonomy.tsv
                cp results.tsv ${CHUNK_OUT}
              " > "${CHUNK_TMP}/chunk_${i}.log" 2>&1

        elif [ "$PIPELINE" == "qiime2" ]; then
            MODEL_PATH="${BASE_DIR}/benchmark/tmp/qiime2_alfa_v1v2_SILVA/tmp_alfa_v1v2_SILVA"
            docker run --rm \
              -v /home/cristian-solano:/home/cristian-solano \
              -w "${CHUNK_TMP}" \
              quay.io/ezlab/qiime2_20228_lemmi16s:v1.0.0_cv1 \
              /bin/bash -c "
                echo 'sample-id,absolute-filepath,direction' > manifest.tsv
                echo -e 'sample-chunk,${CHUNK_DIR}/queryReads1.fq,forward' >> manifest.tsv
                echo -e 'sample-chunk,${CHUNK_DIR}/queryReads2.fq,reverse' >> manifest.tsv
                qiime tools import --type SampleData[PairedEndSequencesWithQuality] --input-path manifest.tsv --output-path demux.qza --input-format PairedEndFastqManifestPhred33
                qiime quality-filter q-score --i-demux demux.qza --p-min-quality 20 --o-filtered-sequences demux-filtered.qza --o-filter-stats demux-filter-stats.qza
                qiime deblur denoise-16S --i-demultiplexed-seqs demux-filtered.qza --p-trim-length 120 --p-jobs-to-start 2 --o-representative-sequences rep-seqs.qza --o-table table.qza --p-sample-stats --o-stats deblur-stats.qza
                qiime feature-classifier classify-sklearn --i-classifier ${MODEL_PATH}/referenceClassificator.qza --i-reads rep-seqs.qza --p-n-jobs 2 --o-classification taxonomy.qza
                qiime taxa collapse --i-table table.qza --i-taxonomy taxonomy.qza --p-level 7 --o-collapsed-table phyla-table.qza
                qiime tools export --input-path phyla-table.qza --output-path .
                biom convert -i feature-table.biom -o results.txt --to-tsv
                python3 /home/cristian-solano/lemmi16s-cluster-backup/lemmi16s/resources/candidate_containers/qiime2_20228_lemmi16s/scripts/editResult.py results.txt results.tsv summary_taxonomy.tsv
                cp results.tsv ${CHUNK_OUT}
              " > "${CHUNK_TMP}/chunk_${i}.log" 2>&1
        fi

        t_end=$(date +%s)
        echo "  [OK] Chunk ${i} finalizo en $((t_end - t_start)) segundos."
    ) &
    PIDS+=($!)
done

# Esperar que los 5 procesos paralelos terminen
echo "[*] Esperando finalizacion de los 5 chunks en paralelo..."
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

echo "[+] Todos los 5 chunks completados con exito."

# 3. Fusion de predicciones
echo "[PASO 3] Fusionando las 5 predicciones..."
PART_FILES=()
for i in {1..5}; do
    PART_FILES+=("${TMP_SPLIT_DIR}/chunk_${i}.predictions.tsv")
done

python3 "${SCRIPT_DIR}/merge_predictions_5.py" \
  -i "${PART_FILES[@]}" \
  -o "$PRED_FINAL"

echo "=========================================================="
echo "[COMPLETADO] Prediccion fusionada lista:"
head -n 15 "$PRED_FINAL"
echo "=========================================================="
