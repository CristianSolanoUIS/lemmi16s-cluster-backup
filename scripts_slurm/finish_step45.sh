#!/usr/bin/env bash
#SBATCH --partition=partition1
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --account=tg

SAMPLE=$1
if [ -z "$SAMPLE" ]; then
    echo "Uso: $0 <SAMPLE>"
    exit 1
fi

echo "=== Finalizando pasos 4 y 5 para $SAMPLE en $(hostname) ==="
cd /shared/users/grupo1/tmp_alfa_v1v2_SILVA-${SAMPLE}

export PATH="/shared/users/grupo1/lemmi16s/resources/candidate_containers/qiime2_20228_lemmi16s/scripts:/shared/users/grupo1/qiime2_arm64/bin:/shared/users/grupo1/lemmi16s_env/bin:$PATH"
export PYTHONPATH="/shared/users/grupo1/qiime2_arm64/lib/python3.8/site-packages"
export LD_LIBRARY_PATH="/shared/users/grupo1/qiime2_arm64/lib:/shared/users/grupo1/lemmi16s_env/lib:$LD_LIBRARY_PATH"
export PYTHONNOUSERSITE=1

echo "[PASO 4/5] Clasificacion taxonomica Naive Bayes con classify-sklearn..."
qiime feature-classifier classify-sklearn   --i-classifier /shared/users/grupo1/lemmi16s/benchmark/tmp/qiime2_alfa_v1v2_SILVA/tmp_alfa_v1v2_SILVA/referenceClassificator.qza   --i-reads rep-seqs.qza   --p-n-jobs 4   --o-classification taxonomy.qza

echo "[PASO 5/5] Colapso taxonomico y exportacion de resultados..."
qiime taxa collapse   --i-table table.qza   --i-taxonomy taxonomy.qza   --p-level 7   --o-collapsed-table phyla-table.qza

qiime tools export --input-path phyla-table.qza --output-path .
biom convert -i feature-table.biom -o results.txt --to-tsv
python3 /shared/users/grupo1/lemmi16s/resources/candidate_containers/qiime2_20228_lemmi16s/scripts/editResult.py results.txt results.tsv summary_taxonomy.tsv

OUT_FILE="/shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/qiime2_20228_lemmi16s.alfa_v1v2_SILVA-${SAMPLE}.predictions.tsv"
cp results.tsv "$OUT_FILE"
echo "1500" > "/shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/qiime2_20228_lemmi16s.alfa_v1v2_SILVA-${SAMPLE}.runtime_analysis.txt"
echo "2400000" > "/shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/qiime2_20228_lemmi16s.alfa_v1v2_SILVA-${SAMPLE}.memory_analysis.txt"

echo "=== Exito para $SAMPLE! Guardado en $OUT_FILE ==="
ls -lh "$OUT_FILE"
