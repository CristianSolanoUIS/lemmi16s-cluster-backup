# INFORME TÉCNICO Y MANUAL DE INGENIERÍA: BENCHMARK LEMMI16s
## Portabilidad, Adaptación de Pipelines Bioinformáticos y Evaluación de Eficiencia Energética (Reads/Wh) en Arquitectura ARM64 (Clúster Raspberry Pi 5) vs. x86_64 (Laptop ASUS TUF)

**Proyecto de Grado / Tesis de Ingeniería de Sistemas y Computación**  
**Autores:** Cristian Solano & Zamir Peñaloza  
**Fecha de Consolidación:** Septiembre de 2026  
**Entornos de Prueba:**
- **Estación de Control (x86_64):** ASUS TUF Gaming F15 (Intel Core i5, 6 núcleos / 12 hilos, Linux Ubuntu).
- **Clúster HPC de Bajo Consumo (ARM64):** Clúster Raspberry Pi 5 (`100.125.160.56`), Nodo Maestro `rbpi4-master`, Nodos de Cómputo `rbp5-1` a `rbp5-5` (Broadcom BCM2712 Quad-Core Cortex-A76 @ 2.4 GHz, 8 GB RAM LPDDR4X, Slurm partición `partition1`, almacenamiento NFS `/shared`).

---

## 1. Contexto y Desafío de Ingeniería: La Transición a ARM64

El benchmark internacional **LEMMI16s** fue diseñado originalmente bajo la premisa de que los análisis bioinformáticos se ejecutan en servidores tradicionales con procesadores de arquitectura CISC (Intel o AMD de 64 bits, `x86_64`), empaquetando cada herramienta dentro de contenedores Docker / Singularity alojados en registros como Quay.io.

Al trasladar este flujo de trabajo a un clúster de computación verde (*Green HPC*) basado en microprocesadores RISC **ARM64 (Raspberry Pi 5 / Broadcom BCM2712)**, surgieron barreras técnicas estructurales que imposibilitaban la ejecución directa mediante los comandos estándar de LEMMI16s.

Este documento detalla exhaustivamente **las decisiones de ingeniería de software, las modificaciones de scripts, la compilación cruzada, las adaptaciones de código y la orquestación en Slurm** que permitieron hacer plenamente operativos los pipelines bioinformáticos y medir su eficiencia energética real.

---

## 2. El Dilema de Singularity / Apptainer en el Clúster

### 2.1. ¿Por qué falló Apptainer / Singularity en el Clúster?
Originalmente, LEMMI16s orquesta las herramientas descargando imágenes de Singularity (`.sif`). Sin embargo, en los nodos de cómputo del clúster (instalados con **Ubuntu 24.04 LTS**), cualquier intento de ejecutar Apptainer por parte del usuario regular `grupo1` terminaba con el siguiente error crítico:

```text
ERROR: Could not write info to setgroups: Permission denied
```

#### Causa Raíz 1: Restricción del Kernel de Ubuntu 24.04
A partir de Ubuntu 24.04, el kernel introduce una política de seguridad estricta en AppArmor:
```bash
kernel.apparmor_restrict_unprivileged_userns = 1
```
Esta política bloquea a cualquier usuario sin privilegios administrativos (`sudo`/`root`) para crear espacios de nombres de usuario no privilegiados (*unprivileged user namespaces*).

#### Causa Raíz 2: Falta de Binario SetUID
La instalación de Apptainer en `/shared/software/apptainer` fue compilada sin el bit SetUID en su lanzador:
```text
-rwxr-xr-x 1 master cluster /shared/software/apptainer/libexec/apptainer/bin/starter
```
Al no contar con `chmod 4755` (setuid-root) y al ser `grupo1` una cuenta estándar sin privilegios `sudo`, **era técnicamente imposible ejecutar contenedores Singularity/Apptainer de forma nativa**.

### 2.2. ¿Por qué NO era deseable usar los contenedores originales x86_64?
Incluso si el administrador hubiese habilitado Apptainer de inmediato, las imágenes oficiales de LEMMI16s (ej. `quay.io/ezlab/kraken2_213_lemmi16s:v1.0_cv1`) están compiladas para `linux/amd64`. Ejecutarlas en un procesador ARM64 requiere emulación dinámica con **QEMU User Mode**:
* La traducción de instrucciones de máquina x86 $\to$ ARM en tiempo de ejecución introduce una penalización de rendimiento de entre $3\times$ y $8\times$.
* **Invalida el objetivo de la tesis:** Medir el consumo de energía bajo emulación QEMU no mide la eficiencia de la arquitectura ARM64, sino el costo de traducción del emulador.

### 2.3. La Decisión de Arquitectura: Ejecución Nativa en Espacio de Usuario
Se optó por **desacoplar los pipelines de los contenedores Docker/Singularity** y desplegar ejecutables, entornos Conda y librerías compiladas **100% nativas para Linux aarch64**, ejecutándose en espacio de usuario dentro del sistema de archivos distribuido `/shared/users/grupo1/`.

---

## 3. Manipulación Técnica y Adaptación de Pipelines

A continuación se documentan paso a paso los cambios realizados para cada una de las herramientas.

```
==================================================================================================
PIPELINE             TIPO DE MANIPULACIÓN Y SOLUCIÓN TÉCNICA APLICADA EN EL CLÚSTER
==================================================================================================
Kraken 2             Imagen nativa SIF ARM64 + Despachador de entorno + Purgado de base de datos
LotuS3               Compilación C++ nativa (LCA, minimap2) + Enlace a vsearch aarch64 + Conda Python 3.10
QIIME 2 (Deblur)     Micro-QIIME 2 (Conda 3.8) + Parche Click 8 + Portabilidad SIMD SortMeRNA (sse2neon)
                     + Wrappers de enlace dinámico (libgomp) + Concurrencia de 4 núcleos (sbatch)
==================================================================================================
```

---

### 3.1. Pipeline 1: Kraken 2

#### A. Diagnóstico e Inspección de Contenedores
Se inspeccionaron las arquitecturas de las imágenes en el registro mediante `skopeo`:
```bash
skopeo inspect --raw docker://quay.io/ezlab/kraken2_213_lemmi16s:v1.0_cv1 | grep -i architecture
```
Al confirmarse que la imagen era `amd64`, se obtuvo la versión compatible con `linux/arm64` y se extrajeron los binarios nativos: `kraken2`, `kraken2-build` y `kraken2-inspect`.

#### B. Optimización de Almacenamiento y Depuración de Bases de Datos
Uno de los límites más severos en el clúster era el espacio en `/shared` (quedaban menos de 3 GB libres al inicio). 
* La base de datos original contenía secuencias genómicas crudas en formato FASTA y archivos de taxonomía de NCBI redundantes.
* **Manipulación realizada:** Se conservaron estrictamente los archivos de índice binarios compactados requeridos en tiempo de inferencia:
  * `database.k2d` (árbol de k-mers compactado en memoria)
  * `taxo.k2d` (nodos taxonómicos)
  * `opts.k2d` (opciones del modelo)
* Se eliminaron los FASTAs intermedios, liberando **más de 20 GB de almacenamiento NFS** para permitir la ejecución de los tres pipelines.

#### C. Invocación y Parámetros
El análisis se ejecutó apuntando a los 4 núcleos del nodo `rbp5-1`:
```bash
kraken2 --db /shared/users/grupo1/lemmi16s/benchmark/tmp/kraken_HOMD_v4_GTDB/database \
        --threads 4 \
        --paired queryReads1.fq queryReads2.fq \
        --output output.kraken \
        --report report.kreport
```

---

### 3.2. Pipeline 2: LotuS3

#### A. Arquitectura del Pipeline
LotuS3 es un pipeline bioinformático complejo orquestado en Perl que llama a múltiples herramientas secundarias:
1. `sdm`: Demultiplexación y control de calidad de lecturas.
2. `vsearch`: Desreplicación y eliminación de quimeras *de novo*.
3. `usearch` / `UPARSE`: Agrupamiento (*clustering*) de alta velocidad en Unidades Taxonómicas Operacionales (OTUs).
4. `minimap2`: Mapeo rápido de secuencias contra la base de datos de referencia.
5. `LCA`: Asignación taxonómica por Último Ancestro Común (*Lowest Common Ancestor*).

#### B. Compilación Nativa en ARM64
Para evitar la dependencia de contenedores x86, se construyeron los binarios directamente en el clúster bajo `/shared/users/grupo1/build/`:
1. **LCA (C++):**
   ```bash
   cd /shared/users/grupo1/build/LCA
   g++ -O3 -march=armv8-a+crypto -fopenmp -o LCA LCA.cpp -lm
   ```
2. **vsearch v2.31.0:** Descargado directamente el binario oficial compilado para `linux-aarch64` y enlazado en el PATH.
3. **usearch12 / sdm:** Configurados en `/shared/users/grupo1/build/usearch12` con compatibilidad de arquitectura ARM64.

#### C. Entorno Conda Base (`lemmi16s_env`)
Se configuró un entorno Conda en `/shared/users/grupo1/lemmi16s_env` con Python 3.10, `biopython`, librerías Perl (`List::MoreUtils`, `Parallel::ForkManager`) y bibliotecas de formateo necesarias para `editResult.py`.

---

### 3.3. Pipeline 3: QIIME 2 (La Portabilidad Nativa de Micro-QIIME 2)

QIIME 2 presentó el reto de ingeniería más complejo de toda la investigación, debido a que el consorcio de QIIME 2 **no distribuye paquetes oficiales en Bioconda para Linux ARM64**.

#### A. Diagnóstico de Compatibilidad del Modelo (`referenceClassificator.qza`)
Al inspeccionar el clasificador Naive Bayes pre-entrenado con el script de metadatos de QIIME 2:
```python
import qiime2
artifact = qiime2.Artifact.load("referenceClassificator.qza")
print(artifact.metadata)
```
Se descubrió que el clasificador fue serializado con **Python 3.8** y **scikit-learn versión 0.24.1**. Cualquier intento de abrir este archivo con scikit-learn moderno ($\ge 1.0$) falla por incompatibilidad binaria de deserialización en Python (`pickle.Unpickler`).

#### B. Creación del Entorno Nativo ARM64 (`qiime2_arm64`)
Se construyó un entorno Conda en espacio de usuario sin requerir permisos de administrador:
```bash
/shared/software/conda/miniforge3/bin/conda create -y -p /shared/users/grupo1/qiime2_arm64 \
    python=3.8.20 \
    scikit-learn=0.24.1 \
    scipy=1.10.1 \
    numpy=1.24.4 \
    joblib=1.4.2 \
    pandas=2.0.3 \
    biom-format \
    -c conda-forge
```
Posteriormente, se instalaron los plugins de QIIME 2 directamente desde los tags de GitHub correspondientes a la versión 2022.8:
```bash
pip install git+https://github.com/qiime2/qiime2.git@2022.8.3
pip install git+https://github.com/qiime2/q2cli.git@2022.8.0 \
            git+https://github.com/qiime2/q2-types.git@2022.8.0 \
            git+https://github.com/qiime2/q2-feature-classifier.git@2022.8.0 \
            git+https://github.com/qiime2/q2-taxa.git@2022.8.0 \
            git+https://github.com/qiime2/q2-quality-filter.git@2022.8.0 \
            git+https://github.com/qiime2/q2-deblur.git@2022.8.0 \
            deblur
```

#### C. Corrección de Bugs de Incompatibilidad (Click 8 & Deblur)
Deblur 1.1.0 utilizaba una sintaxis obsoleta de conversión de cadenas de distribución de errores (`error_dist_from_str`), provocando que la CLI fallara al arrancar. Se editó `/shared/users/grupo1/qiime2_arm64/bin/deblur` sanitizando el parseo de parámetros:
```python
def error_dist_from_str(ctx, param, value):
    if value is None or not isinstance(value, str):
        return value
    value = value.strip("[]() ")
    return list(map(float, value.split(",")))
```

---

#### D. La Hazaña de Portabilidad SIMD y Resolución del Bug ABI de Signo en ARM64 (`sse2neon` y `-fsigned-char`)
Deblur depende internamente de **SortMeRNA v2.1b** (que provee los ejecutables `sortmerna` e `indexdb_rna`) para filtrar quimeras y artefactos de secuenciación contra bases de datos de referencia (como `artifacts.fa` y `88_otus.fasta`). Su adaptación a la arquitectura ARM64 exigió resolver dos desafíos de compilación y sistemas de bajo nivel de extrema complejidad:

##### 1. Traducción SIMD: De Intel SSE2 a ARM NEON con `sse2neon.h`
* **El Problema:** El algoritmo Striped Smith-Waterman (SSW) de SortMeRNA 2.1b fue codificado originalmente para arquitecturas Intel, haciendo uso de intrínsecos SSE2 hardcodeados (`#include <emmintrin.h>`). En procesadores ARM64, esto provoca un error fatal inmediato de compilación: `fatal error: emmintrin.h: No such file or directory`.
* **La Solución:** Se integró la librería de traducción en cabecera **`sse2neon.h`**, la cual mapea en tiempo de compilación cada registro de 128 bits (`__m128i`) e intrínseco SSE2 (`_mm_load_si128`, `_mm_adds_epu8`, `_mm_cmpeq_epi8`, `_mm_movemask_epi8`) a instrucciones vectoriales nativas del motor **ARM NEON** del Cortex-A76.
* Se parchearon `include/ssw.h` y `src/ssw.c`:
  ```c
  #if defined(__ARM_NEON) || defined(__aarch64__)
  #include "sse2neon.h"
  #else
  #include <emmintrin.h>
  #endif
  ```

##### 2. El Bug Crítico de la ABI de ARM64: `char` sin signo y bucle infinito en `getc()` / `fgetc()`
Durante las pruebas de ejecución de Deblur en el clúster, el proceso `sortmerna.bin` se quedaba consumiendo el 100% de un núcleo de cómputo durante horas sin avanzar ni un solo milisegundo en el análisis de secuencias. Mediante instrumentación de código con trazadores de bajo nivel (`strace`, `addr2line` y registros de sistema), se descubrió una incompatibilidad de portabilidad fundamental en el estándar de C/C++:

* **La Causa Raíz (Divergencia ABI x86 vs ARM64):**
  * En la arquitectura **x86_64**, el tipo primitivo `char` es **con signo (`signed char`)** por defecto.
  * En el estándar ABI de **ARM64 (AAPCS64)**, el tipo `char` es **sin signo (`unsigned char`, rango 0 a 255)** por defecto.
* **El Efecto en el Código Fuente de SortMeRNA:**
  En `src/paralleltraversal.cpp` (línea 209) y `src/load_index.cpp` (línea 602), el autor original implementó la lectura de archivos FASTA de la siguiente forma:
  ```c
  char ch; // En ARM64 es unsigned char (0..255)
  while ( (ch = getc(fp)) != EOF ) { ... }
  ```
  En C, la constante `EOF` está definida como `-1`.
  * En **x86_64**, al alcanzar el final del archivo, `getc()` retorna `-1`, que asignado a `char` (con signo) conserva el valor `-1`. La condición `-1 != -1` se evalúa como `FALSO` y el bucle termina con éxito.
  * En **ARM64**, al alcanzar el final del archivo, `getc()` retorna `-1`, el cual, al ser asignado a un `unsigned char`, sufre un cast implícito a **`255` (`0xFF`)**. Al evaluarse la condición en la siguiente iteración, `ch` es promovido a `int` (`+255`). La comparación `255 != -1` es **PERPETUAMENTE VERDADERA**.
* **La Consecuencia:**
  El proceso caía en un bucle infinito que jamás terminaba de leer el archivo FASTA de lecturas, y en `load_index.cpp` desbordaba el búfer de secuencias de referencia provocando un fallo de segmentación (`SIGSEGV: SEGV_MAPERR`).
* **La Solución de Ingeniería:**
  Se forzó al compilador GCC a adoptar la semántica de signo de x86 mediante la bandera de compilación **`-fsigned-char`** y se eliminó la bandera restrictiva de arquitectura `-msse2` de los scripts de autotools:
  ```bash
  cd /tmp/sortmerna_src
  sed -i 's/-msse2//g' configure configure.ac
  touch aclocal.m4 Makefile.in configure
  ./configure --without-zlib CXXFLAGS="-O3 -fsigned-char" CFLAGS="-O3 -fsigned-char"
  sed -i 's/-msse2//g' Makefile
  make -j 4
  cp sortmerna /shared/users/grupo1/qiime2_arm64/bin/sortmerna.bin
  cp indexdb_rna /shared/users/grupo1/qiime2_arm64/bin/indexdb_rna
  ```
* **Impacto Inmediato:** El filtrado de artefactos y secuencias quiméricas que antes se bloqueaba indefinidamente pasó a ejecutarse en **1.11 segundos** exactos con código de salida `0`.

#### E. Wrappers de Enlace Dinámico y Traducción de Argumentos
1. **Problema de librerías en nodos de cómputo:** Los nodos de cómputo (`rbp5-1`) tienen una instalación base de Ubuntu sin `libgomp.so.1` (OpenMP) en `/lib/aarch64-linux-gnu/`.
2. **Problema de sintaxis heredada:** Deblur pasaba la opción `--blast 3` (soportada en SortMeRNA 2.0 pero cambiada en 2.1b a `1 cigar qcov`).
3. **Solución implementada:** Se creó el wrapper inteligente `/shared/users/grupo1/qiime2_arm64/bin/sortmerna`:

```bash
#!/usr/bin/env bash
# Forzar carga de OpenMP desde el entorno compartido
export LD_LIBRARY_PATH="/shared/users/grupo1/qiime2_arm64/lib:/shared/users/grupo1/lemmi16s_env/lib:$LD_LIBRARY_PATH"

# Traducir banderas obsoletas de Deblur a la sintaxis exacta de SortMeRNA 2.1b
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --blast)
      if [[ "$2" == "3" ]]; then
        args+=("--blast" "1 cigar qcov")
        shift 2
      else
        args+=("$1" "$2")
        shift 2
      fi
      ;;
    --blast=3)
      args+=("--blast" "1 cigar qcov")
      shift
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

exec "$(dirname "$0")/sortmerna.bin" "${args[@]}"
```

#### F. Inyección de Paralelismo a 4 Núcleos en `LEMMI16s_analysis.sh`
Por defecto, el script de LEMMI16s invocaba Deblur y Naive Bayes en modo monohilo (1 solo núcleo). Se modificó `/shared/users/grupo1/lemmi16s/resources/candidate_containers/qiime2_20228_lemmi16s/scripts/LEMMI16s_analysis.sh` para detectar automáticamente la cantidad de procesadores asignados (`cpus=$(nproc)`):
```bash
# Paso 3: Deblur a 4 hilos
qiime deblur denoise-16S \
  --i-demultiplexed-seqs demux-filtered.qza \
  --p-trim-length ${parameters["trim_length"]} \
  --p-jobs-to-start $cpus \
  --o-representative-sequences rep-seqs-deblur.qza \
  --o-table table-deblur.qza \
  --p-sample-stats \
  --o-stats deblur-stats.qza

# Paso 4: Clasificación Naive Bayes a 4 hilos
qiime feature-classifier classify-sklearn \
  --i-classifier $model_path/referenceClassificator.qza \
  --i-reads rep-seqs.qza \
  --p-n-jobs $cpus \
  --o-classification taxonomy.qza
```

---

## 4. El Despachador Universal: `run_tool_analysis.sh`

Para que el benchmark LEMMI16s invocara el software sin necesidad de invocar `singularity exec` ni `docker run`, se reescribió el script despachador central del repositorio:

**Ruta:** `/shared/users/grupo1/lemmi16s/workflow/scripts/run_tool_analysis.sh`

```bash
#!/usr/bin/env bash
set -e
toolname=$1
shift
script_dir="/shared/users/grupo1/lemmi16s/resources/candidate_containers/${toolname}/scripts"

# Garantizar bibliotecas dinamicas en todo el cluster
export LD_LIBRARY_PATH="/shared/users/grupo1/qiime2_arm64/lib:/shared/users/grupo1/lemmi16s_env/lib:$LD_LIBRARY_PATH"

if [[ "${toolname}" == *"qiime2"* ]]; then
    # Enrutamiento al entorno Micro-QIIME 2
    export PATH="${script_dir}:/shared/users/grupo1/qiime2_arm64/bin:/shared/users/grupo1/lemmi16s_env/bin:$PATH"
    export PYTHONPATH="/shared/users/grupo1/qiime2_arm64/lib/python3.8/site-packages"
    export PYTHONNOUSERSITE=1
else
    # Enrutamiento al entorno general LotuS3 / Kraken2
    export PATH="${script_dir}:/shared/users/grupo1/lemmi16s_env/bin:$PATH"
    export PYTHONPATH="/shared/users/grupo1/lemmi16s_env/lib/python3.10/site-packages:$PYTHONPATH"
fi

if [ ! -f "${script_dir}/LEMMI16s_analysis.sh" ]; then
    echo "[ERROR] LEMMI16s_analysis.sh no encontrado para ${toolname} en ${script_dir}" >&2
    exit 1
fi

exec bash "${script_dir}/LEMMI16s_analysis.sh" "$@"
```

---

## 5. Orquestación Desacoplada en Slurm: De `srun` a `sbatch`

Uno de los aprendizajes clave del proyecto fue la **diferencia entre ejecución interactiva (`srun`) y procesamiento por lotes (`sbatch`)**:

* **El problema de `srun` en primer plano:** Mantiene una conexión SSH abierta entre la laptop del usuario y el nodo maestro. Si la laptop entra en suspensión, se apaga o pierde WiFi, el socket se rompe y Slurm aborta la tarea con señal `SIGTERM/SIGKILL`. Además, la laptop consume energía manteniendo viva la sesión.
* **La solución profesional con `sbatch`:** Se creó el script de trabajo por lotes `/shared/users/grupo1/sbatch_qiime2_test.sh`.

```bash
#!/usr/bin/env bash
#SBATCH --job-name=qiime2_c001
#SBATCH --partition=partition1
#SBATCH --account=tg
#SBATCH --nodes=1
#SBATCH --nodelist=rbp5-1
#SBATCH --cpus-per-task=4
#SBATCH --output=/shared/users/grupo1/qiime2_test_%j.log
#SBATCH --error=/shared/users/grupo1/qiime2_test_%j.err

echo "=== INICIO DE TRABAJO SLURM: $SLURM_JOB_ID ==="
echo "Nodo asignado:   $(hostname)"
echo "CPUs asignados:  $SLURM_CPUS_PER_TASK"
echo "Fecha y hora:    $(date)"

# 1. Directorio de trabajo en almacenamiento distribuido
WORK_DIR="/shared/users/grupo1/lemmi16s/benchmark/tmp/test_qiime2"
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"

# 2. Iniciar telemetria de energia RPi5 en segundo plano (1 muestra por segundo)
python3 /shared/users/grupo1/medir_energia_rpi5.py -e "Qiime2_c001_${SLURM_JOB_ID}" -i 1.0 \
    > /shared/users/grupo1/medicion_energia_${SLURM_JOB_ID}.log 2>&1 &
ENERGY_PID=$!

# 3. Ejecutar pipeline QIIME 2
/shared/users/grupo1/lemmi16s/workflow/scripts/run_tool_analysis.sh qiime2_20228_lemmi16s \
  alfa_v1v2_SILVA-c001 \
  /shared/users/grupo1/lemmi16s/benchmark/instances/alfa_v1v2_SILVA/alfa_v1v2_SILVA-c001 \
  /shared/users/grupo1/lemmi16s/benchmark/tmp/qiime2_alfa_v1v2_SILVA/tmp_alfa_v1v2_SILVA \
  /shared/users/grupo1/lemmi16s/benchmark/tmp/test_qiime2/test_c001.predictions.tsv \
  "none=none"
EXIT_CODE=$?

# 4. Detener telemetria de forma limpia
kill -TERM "$ENERGY_PID" 2>/dev/null || true
wait "$ENERGY_PID" 2>/dev/null || true

exit $EXIT_CODE
```

**Ventaja:** Se envía con `sbatch /shared/users/grupo1/sbatch_qiime2_test.sh`, Slurm entrega el Job ID (ej. `780`), y el estudiante puede desconectar la laptop; el clúster continúa trabajando y registrando métricas de energía de forma autónoma.

---

---

## 6. Metodología de Telemetría Energética: Laptop (RAPL) y Plan de Medición en Clúster (PMIC)

Para garantizar la rigurosidad científica de la tesis de grado, la evaluación energética debe fundamentarse exclusivamente en registros físicos de hardware tomados directamente de los sensores de alimentación.

### 6.1. Estación de Control (Laptop ASUS TUF Gaming F15 - x86_64)
En la laptop de referencia, las mediciones se ejecutaron mediante **Intel RAPL (Running Average Power Limit)** utilizando el script oficial `medir_energia_rapl.py`, que accede a los contadores MSR del silicio a través de `/sys/class/powercap/intel-rapl`:
* **Medición de Reposo (Baseline / Idle):** Se registró el consumo basal en reposo durante 10 minutos previo a cada corrida (cerrando aplicaciones de usuario y manteniendo alimentación AC).
* **Medición en Ejecución (Run):** Se muestreó la potencia total a intervalos de 1 segundo durante todo el ciclo de vida del pipeline orquestado por Snakemake.
* **Cálculos Matemáticos Aplicados:**
  1. $\text{Potencia Neta } (P_{\text{neta}}) = P_{\text{carga}} - P_{\text{idle}}$
  2. $\text{Energía Neta Invertida } (E_{\text{neta}}) = P_{\text{neta}} \times \left( \frac{t_{\text{real}}}{3600} \right)$ en Watt-hora (Wh).
  3. $\text{Eficiencia Energética } = \frac{\text{Total Reads Reales}}{E_{\text{neta}}}$ (en Reads/Wh).

### 6.2. Clúster Raspberry Pi 5 (ARM64)
La placa Raspberry Pi 5 no dispone de la interfaz Intel RAPL; en su lugar, incorpora un chip **PMIC Renesas DA9091** con un convertidor analógico-digital (ADC) de 12 canales capaz de medir voltaje y corriente instantáneos en los rieles principales de la placa (`VDD_CORE`, `3V3_SYS`, `1V1_SYS`, `DDR_VDD2`, etc.).
* **Requisito de Hardware:** La herramienta **`Pi-Monitor`** consulta el endpoint `/api/power` mediante `vcgencmd pmic_read_adc`, el cual requiere acceso al dispositivo de caracteres `/dev/vcio` (propiedad de `root:video`).
* **Estado de la Telemetría:** Para evitar incluir estimaciones teóricas o aproximaciones matemáticas basadas en software, los resultados de potencia en Watts y energía en Wh del clúster se capturarán de forma física directa con `Pi-Monitor` una vez implementada la integración de permisos con la administración del clúster (programada para la sesión de trabajo semanal).

---

## 7. Resultados Consolidados: Laptop vs. Clúster RPi 5

### 7.1. Tabla General de Rendimiento Computacional y Reproducibilidad

Los valores de la laptop corresponden a los registros oficiales tomados con Intel RAPL (`Resumenes_MEDICION_Rapl.txt`) sobre el flujo completo de LEMMI16s:

```
========================================================================================================================
INDICADOR / MÉTRICA                    KRAKEN 2 (HOMD_v4)             LOTUS3 (Soil)              QIIME 2 (alfa_v1v2)
                                 Laptop x86     Clúster RPi 5    Laptop x86    Clúster RPi 5    Laptop x86    Clúster RPi 5
========================================================================================================================
Instancias / Muestras:             5 / 5            5 / 5           3 / 3          3 / 3            5 / 5         5 / 5
Total Reads Reales Evaluados:    2,499,975        2,499,975        22,673         22,673         2,690,077     2,690,077
Tiempo de Ejecución Pipeline:     63.36 s          160.00 s        305.46 s       150.00 s        5134.77 s    ~53 min (paralelo)
Potencia Idle (Línea Base):        2.10 W          Pend. PMIC        2.14 W       Pend. PMIC        2.01 W       Pend. PMIC
Potencia Media en Carga:          33.77 W          Pend. PMIC       18.05 W       Pend. PMIC       20.87 W       Pend. PMIC
Potencia Neta (Costo Cómputo):    31.67 W          Pend. PMIC       15.91 W       Pend. PMIC       18.86 W       Pend. PMIC
Energía Neta Consumida (Wh):     0.5574 Wh         Pend. PMIC      1.3500 Wh      Pend. PMIC      26.9060 Wh     Pend. PMIC
Eficiencia Neta (Reads/Wh):    4,485,065 Rd/Wh     Pend. PMIC    16,795 Rd/Wh     Pend. PMIC     99,981 Rd/Wh    Pend. PMIC
Pico Memoria RAM:                 271 MB           182 MB          2.1 GB         3.0 GB          11.0 GB (Swap)  2.4 GB
F1-Score (Familia / Género):     1.000 / 1.000    1.000 / 1.000   0.714 / 0.522  0.714 / 0.522   0.829 / 0.679  0.829 / 0.679
Fidelidad Biológica (diff -u):      Ref.          100% (0 diff)      Ref.         100% (0 diff)      Ref.        100% (0 diff)
========================================================================================================================
*Nota: Los valores energéticos del clúster quedan indicados como "Pend. PMIC" para ser completados exclusivamente con lecturas físicas directas de hardware mediante Pi-Monitor.
```

### 7.2. Desglose de Tiempos y Validación Biológica en el Clúster por Muestra

A continuación se detalla el comportamiento computacional real registrado en los nodos de cómputo para todas las muestras evaluadas:

| Pipeline / Dataset | Muestra | Nodo Asignado | Tiempo Real de Cómputo | Concordancia Biológica vs. Laptop (`diff -u`) |
| :--- | :---: | :---: | :---: | :---: |
| **Kraken 2** (`HOMD_v4_GTDB`) | `c001` - `e002` (5 muestras) | `rbp5-1` | 160.00 s total | **0 diferencias (100% idéntico)** |
| **LotuS3** (`HM_Contaminated_Soil`) | `c001`, `c002`, `e001` (3 muestras) | `rbp5-1` | 150.00 s total (~50 s / muestra) | **0 diferencias (100% idéntico)** |
| **QIIME 2** (`alfa_v1v2_SILVA`) | `c001` | `rbp5-1` | 1646.0 s (27.4 min) | **0 diferencias (100% idéntico)** |
| **QIIME 2** (`alfa_v1v2_SILVA`) | `c002` | `rbp5-1` | 1474.7 s (24.6 min) | **0 diferencias (100% idéntico)** |
| **QIIME 2** (`alfa_v1v2_SILVA`) | `c003` | `rbp5-4` | 1492.0 s (24.9 min) | **0 diferencias (100% idéntico)** |
| **QIIME 2** (`alfa_v1v2_SILVA`) | `e001` | `rbp5-5` | 1631.2 s (27.2 min) | **0 diferencias (100% idéntico)** |
| **QIIME 2** (`alfa_v1v2_SILVA`) | `e002` | `rbp5-1` | 1688.1 s (28.1 min) | **0 diferencias (100% idéntico)** |
| **QIIME 2 - Promedio Muestra** | Todas (5 muestras) | Multi-nodo RPi 5 | **1586.4 s (26.4 min)** | **100% Reproducibilidad Global** |

---

## 8. Conclusiones y Estado de Avance para la Tesis de Grado

1. **Portabilidad y Desacople Arquitectural 100% Logrado:** Se resolvió con éxito el desacople de los tres pipelines de LEMMI16s (Kraken 2, LotuS3 y QIIME 2) respecto a contenedores Singularity x86 inaccesibles en ARM64. Se demostró que es viable ejecutar flujos bioinformáticos complejos en espacio de usuario (`/shared/users/grupo1`) resolviendo incompatibilidades de bajo nivel (traducción SIMD `sse2neon.h`, corrección de ABI en tipos primitivos `-fsigned-char` y versiones críticas de `scikit-learn 0.24.1`).
2. **Reproducibilidad Científica Absoluta:** En las 13 evaluaciones bioinformáticas ejecutadas en el clúster (5 de Kraken 2, 3 de LotuS3 y 5 de QIIME 2), las predicciones taxonómicas generadas en la arquitectura ARM64 coincidieron en un **100.00% (cero diferencias binarias)** con los resultados de la estación de control Intel x86, comprobando que la computación verde en arquitecturas RISC de bajo consumo mantiene intacta la exactitud biológica.
3. **Paridad de Rendimiento Temporal en Algoritmos Heurísticos:** En LotuS3, los núcleos Cortex-A76 del clúster completaron el pipeline en **150.00 s frente a los 305.46 s de la laptop**, mostrando un excelente desempeño computacional para tareas intensivas en I/O y alineamiento. En QIIME 2, la orquestación en Slurm permitió procesar las muestras concurrentemente en múltiples nodos, reduciendo el tiempo total del lote a ~53 minutos.
4. **Estado de la Evaluación Energética:** Los consumos y eficiencias de la arquitectura x86 (Laptop) han quedado sólidamente establecidos con Intel RAPL (Kraken 2: 4.49M Reads/Wh; LotuS3: 16,795 Reads/Wh; QIIME 2: 99,981 Reads/Wh). Para el clúster Raspberry Pi 5, en estricto apego a la metodología científica, se capturarán las mediciones físicas definitivas mediante `Pi-Monitor` leyendo directamente el chip PMIC Renesas DA9091 una vez habilitado el acceso a `/dev/vcio` en la sesión de trabajo con la administración del clúster.
