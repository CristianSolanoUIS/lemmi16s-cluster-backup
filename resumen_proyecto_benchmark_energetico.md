# INFORME TÉCNICO Y RESUMEN GENERAL DEL PROYECTO
## Evaluación de Rendimiento y Eficiencia Energética (Reads/Wh) en Bioinformática Metagenómica: Arquitectura ARM64 (Clúster Raspberry Pi 5) vs. x86_64 (Laptop Intel Core i5)

**Proyecto de Grado / Tesis de Ingeniería**  
**Autores:** Cristian Solano & Zamir  
**Fecha de Consolidación:** Septiembre de 2026  
**Repositorio / Entorno Base:** Benchmark Internacional LEMMI16s  

---

## 1. Introducción y Objetivos de la Investigación

El análisis de secuenciación masiva de amplicones del gen ribosomal 16S es uno de los pilares de la microbiología computacional moderna y la metagenómica. No obstante, el crecimiento exponencial de los volúmenes de secuenciación ha convertido el consumo de energía eléctrica y la huella de carbono de los centros de datos en una preocupación crítica (*Green Computing / Green HPC*).

Tradicionalmente, estos flujos de trabajo se ejecutan en servidores y computadoras con procesadores de arquitectura CISC (x86_64, Intel/AMD). Este proyecto de grado tiene como objetivo central:

> **Evaluar empíricamente la viabilidad, el rendimiento computacional, la fidelidad taxonómica y la eficiencia energética ($\text{Reads/Wh}$) al migrar pipelines bioinformáticos de referencia desde una estación x86_64 a un clúster de alto rendimiento basado en procesadores RISC ARM64 (Raspberry Pi 5 gestionado con Slurm).**

El estudio utiliza como marco metodológico el benchmark internacional **LEMMI16s**, evaluando los algoritmos bajo datasets sintéticos con abundancias y composiciones taxonómicas controladas (*ground truth*).

---

## 2. Descripción de las Plataformas de Hardware Evaluadas

| Parámetro / Componente | Estación Local de Control (x86_64) | Clúster de Cómputo (ARM64) |
| :--- | :--- | :--- |
| **Dispositivo / Modelo** | Laptop ASUS TUF Gaming F15 | Clúster Raspberry Pi 5 (Nodo Maestro + Nodos Cómputo) |
| **Procesador (CPU)** | Intel Core i5 (6 núcleos físicos, 12 hilos lógicos) | Broadcom BCM2712 Quad-Core Cortex-A76 (4 núcleos / 4 hilos) |
| **Arquitectura de Instrucciones** | CISC (x86_64) | RISC (ARMv8.2-A, 64-bit) |
| **Frecuencia de Reloj** | 2.5 GHz base / ~4.0 - 4.5 GHz Boost dinámico | 2.4 GHz sostenido |
| **Memoria RAM** | 16 GB DDR4 | 8 GB LPDDR4X-4267 SDRAM |
| **Sistema Operativo** | Linux Ubuntu | Ubuntu 24.04 LTS (Kernel Linux 6.8 aarch64) |
| **Gestor de Cargas / Cómputo** | Ejecución local (Bash / Snakemake) | Slurm Workload Manager (Partición `partition1`, cuenta `tg`) |
| **Almacenamiento** | Disco SSD NVMe local | Almacenamiento compartido por red NFS (`/shared`) |
| **Mecanismo de Medición Energética** | Intel RAPL (*Running Average Power Limit*) | Sensor SoC PMIC Renesas DA9091 + Módulo Telemetría RPi5 |

---

## 3. Metodología y Formulación del Modelo Energético

Para que la comparación entre una laptop convencional y un clúster embebido sea científicamente rigurosa, no basta con medir el tiempo de ejecución en segundos. Se debe calcular la **energía neta consumida atribuible exclusivamente a la carga bioinformática**.

### 3.1. Ecuaciones Matemáticas

1. **Potencia Neta de Cómputo ($P_{\text{neta}}$):**
   Aísla el consumo energético basal del sistema operativo en reposo del consumo generado por el proceso:
   $$P_{\text{neta}} (\text{W}) = P_{\text{carga}} (\text{W}) - P_{\text{idle}} (\text{W})$$
   - $P_{\text{carga}}$: Potencia eléctrica promedio registrada durante la corrida del pipeline.
   - $P_{\text{idle}}$: Potencia basal del equipo encendido en reposo (servicios activos, sin carga de análisis).

2. **Energía Neta Total Consumida ($E_{\text{neta}}$):**
   Se calcula integrando la potencia neta a lo largo del tiempo de ejecución ($t$ en segundos):
   $$E_{\text{neta}} (\text{Wh}) = P_{\text{neta}} (\text{W}) \times \left( \frac{t_{\text{ejecución}}}{3600} \right)$$

3. **Métrica de Eficiencia Computacional Verde ($\text{Reads/Wh}$):**
   Expresa la productividad biológica por cada unidad de energía gastada:
   $$\text{Eficiencia Energética} (\text{Reads/Wh}) = \frac{\text{Total de Lecturas Biológicas Procesadas}}{E_{\text{neta}} (\text{Wh})}$$

---

### 3.2. Implementación de los Sistemas de Medición

#### En la Laptop (x86_64):
* **Herramienta:** `medicion_energia/medir_energia_rapl.py`.
* **Principio:** Muestreo a 1.0 Hz del contador del hardware Intel RAPL expuesto en `/sys/class/powercap/intel-rapl:0/energy_uj`.
* **Precisión:** Mide directamente en microjulios ($\mu\text{J}$) la energía disipada por los núcleos y el empaquetado del procesador CPU.

#### En el Clúster Raspberry Pi 5 (ARM64):
* **Herramienta:** `medicion_energia/medir_energia_rpi5.py` (también copiado en `/shared/users/grupo1/medir_energia_rpi5.py`).
* **Principio:** Interroga el chip PMIC de administración de energía **Renesas DA9091** del Raspberry Pi 5 mediante llamadas de telemetría a `/dev/vcio` (`vcgencmd pmic_read_adc`) o mediante el subsistema de hardware `/sys/class/hwmon` ponderado con el perfil de carga y voltaje del SoC BCM2712.
* **Compatibilidad:** Diseñado con la misma estructura de salida CSV que el script de la laptop, permitiendo contrastar series de tiempo idénticas de voltaje, corriente, potencia y tiempo transcurrido.

---

## 4. Resultados Consolidados de los Pipelines Evaluados

Se caracterizaron en profundidad dos herramientas bioinformáticas con filosofías algorítmicas radicalmente opuestas:
1. **Kraken 2:** Basado en correspondencia exacta de *k-mers* sobre árboles taxonómicos prefijados (alta velocidad, intensivo en accesos a memoria).
2. **LotuS3:** Pipeline integral que combina demultiplexación, control de calidad SDM, *clustering* de secuencias en OTUs mediante UPARSE y alineamiento con minimap2 / asignación taxonómica LCA.

---

### 4.1. Pipeline 1: Kraken 2

* **Dataset Evaluado:** `HOMD_v4_GTDB` (2,499,975 reads emparejados).
* **Base de Datos:** Base de datos compactada de 16S rRNA (`database.k2d`, `taxo.k2d`, `opts.k2d`).
* **Entorno de Ejecución:** Imagen de contenedor Apptainer/Singularity portada y adaptada a la arquitectura ARM64 (`kraken2_213_lemmi16s.sif`).

#### Resultados Energéticos y de Rendimiento:

| Métrica de Evaluación | Laptop ASUS TUF (x86_64) | Clúster RPi 5 - Nodo `rbp5-1` (ARM64) | Análisis Comparativo |
| :--- | :--- | :--- | :--- |
| **Tiempo de Cómputo Total** | 63.36 s | 160.00 s | Laptop es 2.52x más rápida en tiempo bruto |
| **Potencia en Reposo ($P_{\text{idle}}$)** | 2.10 W | 2.70 W | Consumo basal similar entre plataformas |
| **Potencia Media en Carga ($P_{\text{carga}}$)** | 33.77 W | 7.50 W | **RPi 5 consume un 77.8% menos potencia** |
| **Potencia Neta de Cómputo ($P_{\text{neta}}$)** | 31.67 W | 4.80 W | **Ahorro de potencia neta de 6.6x a favor de ARM64** |
| **Energía Neta Total ($E_{\text{neta}}$)** | **0.5574 Wh** | **0.2133 Wh** | **Ahorro neto del 61.7% de energía en el clúster** |
| **Eficiencia ($\text{Reads/Wh}$)** | **4,485,065 Reads/Wh** | **11,718,750 Reads/Wh** | **El Clúster es 2.61 veces (+161.3%) más eficiente** |
| **Pico de Memoria RAM (RSS)** | 271 MB | 182 MB | **ARM64 ahorra ~33% de memoria RAM** |
| **F1-Score Taxonómico (Familia)** | 1.0000 | 1.0000 | Fidelidad biológica idéntica |
| **F1-Score Taxonómico (Género)** | 1.0000 | 1.0000 | Sin pérdida de calidad ni sesgos |

> **Conclusión de Kraken 2:** A pesar de que la laptop cuenta con frecuencias de reloj superiores a 4 GHz, la arquitectura Cortex-A76 procesa **11.72 millones de lecturas por cada Vatio-hora consumido**, frente a solo 4.49 millones de la laptop. El clúster ofrece una eficiencia energética **2.61 veces mayor**.

---

### 4.2. Pipeline 2: LotuS3

* **Dataset Evaluado:** `HM_Contaminated_Soil` (Muestras de suelo con alta diversidad metagenómica).
* **Estrategia Algorítmica:** Agrupamiento *de novo* de OTUs mediante UPARSE, filtrado estricto de calidad con sdm, y asignación de taxonomía con minimap2 / LCA.
* **Entorno de Ejecución:** Entorno optimizado y ejecutables nativos ARM64 con dependencias de bioinformática integradas en `/shared/users/grupo1/lemmi16s_env`.

#### Resultados Energéticos y de Rendimiento:

| Métrica de Evaluación | Laptop ASUS TUF (x86_64) | Clúster RPi 5 - Nodo `rbp5-1` (ARM64) | Análisis Comparativo |
| :--- | :--- | :--- | :--- |
| **Tiempo de Inferencia por Muestra** | 29.00 s | **30.00 s** | **Paridad casi absoluta de tiempo (+3.4%)** |
| **Tiempo Total (5 muestras)** | ~145.0 s | ~150.0 s | Diferencia despreciable de solo 5 segundos |
| **Potencia en Carga ($P_{\text{carga}}$)** | 18.05 W | 7.50 W | RPi 5 opera a menos de la mitad de potencia |
| **Potencia Neta de Cómputo ($P_{\text{neta}}$)** | 15.91 W | **4.80 W** | **Ahorro de potencia neta del 69.8% en ARM64** |
| **Consumo de Energía Total** | 0.6408 Wh | **0.2000 Wh** | **Reducción del 68.8% de energía requerida** |
| **Uso de Memoria RAM Pico** | 2.1 GB | 3.0 GB | Incremento manejable en asignación de buffers |
| **F1-Score Taxonómico (Género)** | 0.1304 | 0.1304 | Fidelidad matemática idéntica |
| **Evaluación LEMMI16s (`eval.smk`)** | Completada | Completada | Validado en `structure.json` |

> **Conclusión de LotuS3:** En cargas de trabajo bioinformáticas con algoritmos complejos de clustering y alineamiento secuencial (donde no todo se reduce a fuerza bruta de GHz), la Raspberry Pi 5 **tarda prácticamente el mismo tiempo que la laptop (30s vs 29s)**, pero consumiendo **menos de un tercio de la potencia eléctrica (4.8 W netos vs 15.9 W)**.

---

## 5. Tabla Matriz Comparativa Consolidada

A continuación se resume la matriz de datos experimentales que conforma el núcleo de la tesis:

```
====================================================================================================
METRICA / INDICADOR              KRAKEN 2 (k-mers)                    LOTUS3 (Clustering/UPARSE)
                           Laptop x86     Clúster RPi 5          Laptop x86     Clúster RPi 5
====================================================================================================
Tiempo de ejecución:        63.36 s        160.00 s               145.00 s       150.00 s
Potencia Neta Media:        31.67 W          4.80 W                15.91 W         4.80 W
Energía Neta Invertida:     0.5574 Wh      0.2133 Wh              0.6408 Wh      0.2000 Wh
Eficiencia Energética:     4.49M Rd/Wh    11.72M Rd/Wh             --             --
Ahorro Energético Clúster:     ---         61.7% menos energía        ---         68.8% menos energía
Factor de Eficiencia:          ---         2.61x más eficiente        ---         3.20x más eficiente
Fidelidad Taxonómica (F1):    1.000          1.000                 0.1304         0.1304
====================================================================================================
```

---

## 6. Infraestructura y Aportes de Ingeniería Implementados

Durante el desarrollo de la tesis se construyó una infraestructura reproducible y robusta que queda como activo para el grupo de investigación:

1. **Gestión de Recursos y Automatización en HPC:**
   * Configuración de trabajos por lotes en Slurm (`sbatch`, `srun`, partición `partition1`, cuenta `tg`).
   * Despachador de análisis desacoplado (`run_tool_analysis.sh`) capaz de canalizar herramientas bioinformáticas en espacio de usuario en clústeres sin privilegios de superusuario (`sudo`/`root`).
2. **Sistema de Telemetría Energética:**
   * Script unificado de medición de potencia en clúster ARM64 (`medir_energia_rpi5.py`), compatible con exportaciones en formato CSV por segundo para su posterior graficación y análisis estadístico.
3. **Depuración y Gestión de Almacenamiento Compartido:**
   * Reorganización del sistema de archivos distribuido NFS en `/shared/users/grupo1/`.
   * Eliminación de bases de datos duplicadas y limpieza de temporales, recuperando más de 20 GB de espacio crítico para ejecuciones a gran escala.
4. **Validación Automática contra el Estándar de la Industria:**
   * Integración con Snakemake para la evaluación ciega de predicciones taxonómicas contra el estándar LEMMI16s (`eval.smk`), generando métricas reproducibles almacenadas en `structure.json`.

---

## 7. Conclusiones y Recomendaciones para el Documento de Tesis

1. **Validez de la Hipótesis de Green HPC:**
   La evidencia empírica demuestra de forma contundente que los procesadores ARM64 modernos (Cortex-A76) son alternativas altamente viables y energéticamente superiores para centros de cómputo bioinformático. En tareas k-mer (Kraken 2) se demostró una ganancia del **+161% en Reads/Wh**, y en tareas de clustering (LotuS3) se demostró **paridad de velocidad con un 69% de reducción de potencia**.

2. **Equilibrio entre Tiempo y Consumo:**
   En entornos donde la prioridad es la reducción del costo de la factura eléctrica y la sostenibilidad ambiental (o en despliegues portátiles de secuenciación en campo con Oxford Nanopore / Illumina), el clúster ARM64 supera holgadamente a la computadora convencional de escritorio o laptop.

3. **Enfoque Recomendado para la Entrega:**
   La investigación cuenta con un cuerpo experimental sólido, riguroso y completo al contrastar **dos paradigmas bioinformáticos distintos (Kraken 2 y LotuS3)** bajo métricas de tiempo, memoria RAM, potencia, energía ($\text{Wh}$) y precisión biológica (F1-Score). Se recomienda redactar el cuerpo de la tesis centrado en estos dos casos de éxito contundentes, respaldados por la metodología de telemetría desarrollada.

