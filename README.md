# Respaldo Completo del Trabajo del Grupo 1 - LEMMI 16S en Clúster ARM64

Este repositorio contiene el respaldo integral de todo el código, scripts de Slurm, recetas de entornos Conda, herramientas de compilación nativas ARM64, telemetría de monitoreo energético y las predicciones finales generadas durante el benchmark de pipelines bioinformáticos de 16S en el clúster de Raspberry Pi.

---

## 📁 Estructura del Repositorio

```text
lemmi16s-cluster-backup/
├── scripts_slurm/                      # Scripts de ejecución Slurm para nodos del clúster
│   ├── sbatch_qiime2_single.sh         # Ejecución parametrizada por muestra de QIIME 2
│   ├── finish_step45.sh                # Consolidación de pasos finales en QIIME 2
│   └── sbatch_qiime2_test.sh           # Pruebas de validación de Slurm
├── lemmi16s/                           # Framework de benchmarking adaptado para ARM64
│   ├── workflow/                       # Reglas de Snakemake, scripts wrappers y medidores
│   │   ├── rules/                      # Reglas de análisis, evaluación y samples
│   │   └── scripts/                    # Scripts ejecutables y wrappers de herramientas
│   ├── resources/                      # Wrappers de contenedores y utilitarios
│   │   ├── candidate_containers/       # Scripts adaptados para QIIME 2, LotuS3, Kraken 2
│   │   └── art_bin_MountRainier/       # Binarios de simulación de lecturas
│   ├── benchmark/
│   │   ├── analysis_outputs/           # 13 PREDICCIONES Y MÉTRICAS OBTENIDAS EN EL CLÚSTER
│   │   ├── evaluations/                # Tablas de AUPRC, F1-score, L2, precisión y recall
│   │   ├── final_results/              # Reportes consolidados en JSON y TSV
│   │   └── yaml/                       # Definiciones de ejecuciones y benchmarks
│   └── config/                         # Configuraciones de Snakemake
├── build/                              # Código fuente y compilación de herramientas nativas ARM64
│   ├── LCA/                            # Herramienta LCA (Lowest Common Ancestor) compilada en ARM64
│   └── usearch12/                      # Código fuente y binario usearch12 para ARM64
├── Pi-Monitor/                         # Servicio web Flask para monitoreo de telemetría de hardware
├── medicion_energia/                   # Scripts de monitoreo de energía y muestreo PMIC
│   └── medir_energia_rpi5.py           # Polling de voltaje, corriente y potencia en Raspberry Pi 5
├── mediciones_historicas/              # Registros CSV de consumo de energía medidos en clúster
├── logs_slurm/                         # Logs completos de salida (stdout/stderr) de las corridas
├── qiime2_arm64_environment.yml        # Receta exportada para recrear el entorno Conda de QIIME 2 en ARM64
├── lemmi16s_env_environment.yml        # Receta exportada para recrear el entorno Conda de LEMMI 16S
├── comandos_ejecucion_pipelines.md     # Guía exacta comando a comando para reproducir cada pipeline
├── informe_benchmark_cluster_zamir.md  # Informe técnico oficial del benchmark Laptop (RAPL) vs Clúster
└── resumen_proyecto_benchmark_energetico.md # Resumen ejecutivo del proyecto
```

---

## ⚡ 1. Cómo Recrear los Entornos Conda en ARM64

Para replicar exactamente los entornos en cualquier máquina o tarjeta ARM64:

```bash
# 1. Recrear entorno de LEMMI 16S (Python 3.10, Snakemake, biom-format)
conda env create -f lemmi16s_env_environment.yml

# 2. Recrear entorno de QIIME 2 Amplicon para ARM64
conda env create -f qiime2_arm64_environment.yml
```

---

## 🔬 2. Resumen de las 13 Predicciones Obtenidas en el Clúster

Todas las predicciones se encuentran preservadas en `lemmi16s/benchmark/analysis_outputs/`:

| Pipeline | Muestras Procesadas | Formato Salida | Estado |
| :--- | :--- | :--- | :--- |
| **LotuS3 3.03** | `HM_Contaminated_Soil` (`c001`, `c002`, `e001`) | `.predictions.tsv` + memorias/tiempos | ✅ Completado |
| **Kraken 2 2.1.3** | `HOMD_v4_GTDB` (`c001`, `c002`, `c003`, `e001`, `e002`) | `.predictions.tsv` + memorias/tiempos | ✅ Completado |
| **QIIME 2 2022.8** | `alfa_v1v2_SILVA` (`c001`, `c002`, `c003`, `e001`, `e002`) | `.predictions.tsv` + memorias/tiempos | ✅ Completado |

---

## 🚀 3. Ejecución en Slurm

Los scripts utilizados para correr en paralelo en los nodos del clúster se encuentran en `scripts_slurm/`. Ejemplo:

```bash
sbatch scripts_slurm/sbatch_qiime2_single.sh c001
sbatch scripts_slurm/sbatch_qiime2_single.sh c002
sbatch scripts_slurm/sbatch_qiime2_single.sh c003
sbatch scripts_slurm/sbatch_qiime2_single.sh e001
sbatch scripts_slurm/sbatch_qiime2_single.sh e002
```

Para más detalles paso a paso, consultar `comandos_ejecucion_pipelines.md`.
