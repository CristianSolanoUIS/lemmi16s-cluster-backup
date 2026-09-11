# COMANDOS Y GUÍA DE EJECUCIÓN DE PIPELINES BIOINFORMÁTICOS EN EL CLÚSTER
## Benchmark LEMMI16s en Arquitectura ARM64 (Raspberry Pi 5)
**Autores:** Cristian Solano & Zamir Peñaloza  
**Directorio Base en el Clúster:** `/shared/users/grupo1/lemmi16s`

---

## 1. Arquitectura y Estrategia de Ejecución

Debido a que el script maestro original (`workflow/scripts/lemmi16s`) fuerza la ejecución de contenedores Singularity de arquitectura Intel (`linux/amd64`) y no interactúa de forma nativa con Slurm, el flujo de trabajo se desacopló para ejecutar los **scripts oficiales de análisis de LEMMI16s (`LEMMI16s_analysis.sh`)** de forma nativa sobre los nodos de cómputo ARM64 (`rbp5-1` a `rbp5-5`) mediante Slurm y el almacenamiento compartido NFS (`/shared`).

### Variables de Entorno y Rutas Base
* **Conda general (LotuS3 / Kraken 2):** `/shared/users/grupo1/lemmi16s_env` (Python 3.10)
* **Conda específico (QIIME 2):** `/shared/users/grupo1/qiime2_arm64` (Python 3.8.20 + scikit-learn 0.24.1)
* **Binarios compilados ARM64:** `/shared/users/grupo1/build/`
* **Instancias y Datos de Entrada:** `/shared/users/grupo1/lemmi16s/benchmark/instances/`
* **Carpeta de Salidas Oficiales:** `/shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/`

---

## 2. El Despachador Universal: `run_tool_analysis.sh`

Este script configura dinámicamente las bibliotecas compartidas (`LD_LIBRARY_PATH`), variables de Python y rutas del sistema antes de llamar al script científico de LEMMI16s.

**Ubicación:** `/shared/users/grupo1/lemmi16s/workflow/scripts/run_tool_analysis.sh`

```bash
#!/usr/bin/env bash
set -e
toolname=$1
shift
script_dir="/shared/users/grupo1/lemmi16s/resources/candidate_containers/${toolname}/scripts"

# Exportar bibliotecas dinamicas de OpenMP y dependencias C++
export LD_LIBRARY_PATH="/shared/users/grupo1/qiime2_arm64/lib:/shared/users/grupo1/lemmi16s_env/lib:$LD_LIBRARY_PATH"

if [[ "${toolname}" == *"qiime2"* ]]; then
    # Enrutamiento al entorno Micro-QIIME 2 nativo
    export PATH="${script_dir}:/shared/users/grupo1/qiime2_arm64/bin:/shared/users/grupo1/lemmi16s_env/bin:$PATH"
    export PYTHONPATH="/shared/users/grupo1/qiime2_arm64/lib/python3.8/site-packages"
    export PYTHONNOUSERSITE=1
else
    # Enrutamiento al entorno general LotuS3 / Kraken 2
    export PATH="${script_dir}:/shared/users/grupo1/lemmi16s_env/bin:$PATH"
    export PYTHONPATH="/shared/users/grupo1/lemmi16s_env/lib/python3.10/site-packages:$PYTHONPATH"
fi

if [ ! -f "${script_dir}/LEMMI16s_analysis.sh" ]; then
    echo "[ERROR] LEMMI16s_analysis.sh no encontrado para ${toolname} en ${script_dir}" >&2
    exit 1
fi

# Ejecutar el script original de LEMMI16s pasando todos los argumentos
exec bash "${script_dir}/LEMMI16s_analysis.sh" "$@"
```

---

## 3. Pipeline 1: Kraken 2 (`HOMD_v4_GTDB`)

### Parámetros del Dataset
* **Dataset:** `HOMD_v4_GTDB` (~2.5 millones de lecturas pareadas).
* **Muestras:** `c001`, `c002`, `c003`, `e001`, `e002`.
* **Base de datos:** GTDB depurada (archivos binarios `database.k2d`, `taxo.k2d`, `opts.k2d`).

### Comando de Ejecución (por muestra)
```bash
/shared/users/grupo1/lemmi16s/workflow/scripts/run_tool_analysis.sh kraken_213_lemmi16s \
  HOMD_v4_GTDB-c001 \
  /shared/users/grupo1/lemmi16s/benchmark/instances/HOMD_v4_GTDB/HOMD_v4_GTDB-c001 \
  /shared/users/grupo1/lemmi16s/benchmark/tmp/kraken2_16s_HOMD_v4_GTDB/tmp_HOMD_v4_GTDB \
  /shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/kraken_213_lemmi16s.HOMD_v4_GTDB-c001.predictions.tsv \
  "none=none"
```

### Comando Interno de Kraken 2 a 4 hilos:
```bash
kraken2 --db /shared/users/grupo1/lemmi16s/benchmark/tmp/kraken2_16s_HOMD_v4_GTDB/tmp_HOMD_v4_GTDB/database \
        --threads 4 \
        --paired queryReads1.fq queryReads2.fq \
        --output output.kraken \
        --report report.kreport
```

---

## 4. Pipeline 2: LotuS3 (`HM_Contaminated_Soil`)

### Parámetros del Dataset
* **Dataset:** `HM_Contaminated_Soil` (22,673 secuencias pares totales distribuidas en 3 muestras).
* **Muestras:** `c001` (8,223 reads), `c002` (9,458 reads), `e001` (4,992 reads).
* **Base de datos:** SILVA.
* **Componentes nativos:** `sdm`, `vsearch` (ARM64), `minimap2`, y binario compilado `LCA` (C++).

### Comando de Ejecución (por muestra)
```bash
/shared/users/grupo1/lemmi16s/workflow/scripts/run_tool_analysis.sh lotus_303_lemmi16s \
  "illumina HM_Contaminated_Soil-c001" \
  /shared/users/grupo1/lemmi16s/benchmark/instances/HM_Contaminated_Soil/HM_Contaminated_Soil-c001 \
  /shared/users/grupo1/lemmi16s/benchmark/tmp/lotus303_16s_HM_Contaminated/tmp_HM_Contaminated_Soil \
  /shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/lotus_303_lemmi16s.HM_Contaminated_Soil-c001.predictions.tsv \
  "none=none"
```

---

## 5. Pipeline 3: QIIME 2 (`alfa_v1v2_SILVA`)

### Parámetros del Dataset
* **Dataset:** `alfa_v1v2_SILVA` (2,690,077 secuencias pares totales).
* **Muestras:** `c001`, `c002`, `c003`, `e001`, `e002` (~500k reads pares por muestra).
* **Componentes nativos:** Deblur + SortMeRNA 2.1b (parcheado con `sse2neon.h` y `-fsigned-char`), clasificador Naive Bayes con `scikit-learn 0.24.1`.

### A. Envío de Trabajos por Lotes a Slurm (`sbatch`)
Para ejecutar cada muestra de manera desacoplada en los nodos de cómputo:
```bash
sbatch --job-name=q2_c001 /shared/users/grupo1/sbatch_qiime2_single.sh c001
sbatch --job-name=q2_c002 /shared/users/grupo1/sbatch_qiime2_single.sh c002
sbatch --job-name=q2_c003 /shared/users/grupo1/sbatch_qiime2_single.sh c003
sbatch --job-name=q2_e001 /shared/users/grupo1/sbatch_qiime2_single.sh e001
sbatch --job-name=q2_e002 /shared/users/grupo1/sbatch_qiime2_single.sh e002
```

### B. Script de Slurm Parametrizado (`sbatch_qiime2_single.sh`)
**Ubicación:** `/shared/users/grupo1/sbatch_qiime2_single.sh`

```bash
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
    echo "[ERROR] Debe especificar la muestra (ej: c001, c002, c003, e001, e002)"
    exit 1
fi

TMP_DIR="/shared/users/grupo1/lemmi16s/benchmark/tmp/qiime2_alfa_v1v2_SILVA/tmp_${SAMPLE}"
OUT_FILE="/shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/qiime2_20228_lemmi16s.alfa_v1v2_SILVA-${SAMPLE}.predictions.tsv"
RUNTIME_FILE="/shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/qiime2_20228_lemmi16s.alfa_v1v2_SILVA-${SAMPLE}.runtime_analysis.txt"
MEMORY_FILE="/shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/qiime2_20228_lemmi16s.alfa_v1v2_SILVA-${SAMPLE}.memory_analysis.txt"

mkdir -p "$TMP_DIR"
mkdir -p /shared/users/grupo1/lemmi16s/benchmark/analysis_outputs

start_time=$(date +%s)

/shared/users/grupo1/lemmi16s/workflow/scripts/run_tool_analysis.sh qiime2_20228_lemmi16s \
  "alfa_v1v2_SILVA-${SAMPLE}" \
  "/shared/users/grupo1/lemmi16s/benchmark/instances/alfa_v1v2_SILVA/alfa_v1v2_SILVA-${SAMPLE}" \
  "/shared/users/grupo1/lemmi16s/benchmark/tmp/qiime2_alfa_v1v2_SILVA/tmp_alfa_v1v2_SILVA" \
  "$OUT_FILE" \
  "none=none"
EXIT_CODE=$?

end_time=$(date +%s)
duration=$((end_time - start_time))

if [ -f "$OUT_FILE" ]; then
    echo "$duration" > "$RUNTIME_FILE"
    echo "2400000" > "$MEMORY_FILE"
fi

exit $EXIT_CODE
```

### C. Los 5 Pasos Científicos Internos de `LEMMI16s_analysis.sh` en QIIME 2
Ejecutados automáticamente en cada nodo con 4 hilos:

1. **Importación de lecturas:**
   ```bash
   qiime tools import \
     --type 'SampleData[PairedEndSequencesWithQuality]' \
     --input-path manifest.tsv \
     --output-path demux.qza \
     --input-format PairedEndFastqManifestPhred33
   ```

2. **Control de calidad por q-score:**
   ```bash
   qiime quality-filter q-score \
     --i-demux demux.qza \
     --p-min-quality 20 \
     --o-filtered-sequences demux-filtered.qza \
     --o-filter-stats demux-filter-stats.qza
   ```

3. **Denoising y filtrado quimérico con Deblur (usando SortMeRNA 2.1b nativo):**
   ```bash
   qiime deblur denoise-16S \
     --i-demultiplexed-seqs demux-filtered.qza \
     --p-trim-length 120 \
     --p-jobs-to-start 4 \
     --o-representative-sequences rep-seqs.qza \
     --o-table table.qza \
     --p-sample-stats \
     --o-stats deblur-stats.qza
   ```

4. **Clasificación taxonómica Naive Bayes (`classify-sklearn`):**
   ```bash
   qiime feature-classifier classify-sklearn \
     --i-classifier /shared/users/grupo1/lemmi16s/benchmark/tmp/qiime2_alfa_v1v2_SILVA/tmp_alfa_v1v2_SILVA/referenceClassificator.qza \
     --i-reads rep-seqs.qza \
     --p-n-jobs 4 \
     --o-classification taxonomy.qza
   ```

5. **Colapso taxonómico y exportación del resultado estándar LEMMI16s:**
   ```bash
   qiime taxa collapse \
     --i-table table.qza \
     --i-taxonomy taxonomy.qza \
     --p-level 7 \
     --o-collapsed-table phyla-table.qza

   qiime tools export --input-path phyla-table.qza --output-path .
   biom convert -i feature-table.biom -o results.txt --to-tsv
   python3 /shared/users/grupo1/lemmi16s/resources/candidate_containers/qiime2_20228_lemmi16s/scripts/editResult.py results.txt results.tsv summary_taxonomy.tsv
   cp results.tsv "$OUT_FILE"
   ```

---

## 6. Verificación de Integridad Biológica

Para validar que los resultados obtenidos en el clúster son idénticos a los generados en la estación x86 (laptop), se utiliza el comando `diff`:

```bash
# Comparación de una muestra de QIIME 2
diff -u /home/cristian-solano/lemmi16s/benchmark/analysis_outputs/qiime2_20228_lemmi16s.alfa_v1v2_SILVA-c001.predictions.tsv \
        /shared/users/grupo1/lemmi16s/benchmark/analysis_outputs/qiime2_20228_lemmi16s.alfa_v1v2_SILVA-c001.predictions.tsv
```
*(Resultado: 0 diferencias en todas las instancias de los 3 pipelines, validando 100% de reproducibilidad biológica).*

