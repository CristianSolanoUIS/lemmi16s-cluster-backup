#!/usr/bin/env python3
"""
split_query_reads_5.py
Divide un conjunto de lecturas FASTQ (queryReads1.fq y queryReads2.fq o single-end)
en exactamente 5 partes iguales (1 para cada uno de los 5 nodos del cluster),
preservando la integridad de bloques de 4 líneas y la sincronización de pares.
"""

import os
import sys
import gzip
import shutil
import argparse

def open_fastq(path, mode="rt"):
    if path.endswith(".gz"):
        return gzip.open(path, mode)
    return open(path, mode)

def count_reads_fast(fastq_path):
    """Cuenta el número de lecturas (líneas / 4) rápidamente."""
    lines = 0
    with open_fastq(fastq_path, "rt") as f:
        for _ in f:
            lines += 1
    return lines // 4

def split_fastq(input_dir, output_dir, num_chunks=5):
    os.makedirs(output_dir, exist_ok=True)

    # Identificar si es paired-end o single-end
    r1_candidates = ["queryReads1.fq", "queryReads1.fastq", "queryReads1.fq.gz", "queryReads1.fastq.gz"]
    r2_candidates = ["queryReads2.fq", "queryReads2.fastq", "queryReads2.fq.gz", "queryReads2.fastq.gz"]
    se_candidates = ["queryReads.fq", "queryReads.fastq", "queryReads.fq.gz", "queryReads.fastq.gz"]

    r1_file = None
    r2_file = None
    se_file = None

    for f in r1_candidates:
        p = os.path.join(input_dir, f)
        if os.path.exists(p):
            r1_file = p
            break

    for f in r2_candidates:
        p = os.path.join(input_dir, f)
        if os.path.exists(p):
            r2_file = p
            break

    if not r1_file:
        for f in se_candidates:
            p = os.path.join(input_dir, f)
            if os.path.exists(p):
                se_file = p
                break

    if not r1_file and not se_file:
        sys.exit(f"[ERROR] No se encontraron queryReads en {input_dir}")

    is_paired = (r1_file is not None and r2_file is not None)
    reference_file = r1_file if is_paired else se_file

    print(f"[*] Analizando dataset en {input_dir}...")
    print(f"[*] Modo: {'Paired-End' if is_paired else 'Single-End'}")

    total_reads = count_reads_fast(reference_file)
    print(f"[*] Total de lecturas identificadas: {total_reads:,}")

    if total_reads < num_chunks:
        sys.exit(f"[ERROR] No hay suficientes lecturas ({total_reads}) para dividir en {num_chunks} chunks.")

    # Calcular tamaño de cada chunk
    base_chunk_size = total_reads // num_chunks
    remainder = total_reads % num_chunks
    chunk_sizes = [base_chunk_size + (1 if i < remainder else 0) for i in range(num_chunks)]

    print(f"[*] Distribución de lecturas en {num_chunks} chunks: {chunk_sizes}")

    # Preparar directorios de salida
    chunk_dirs = []
    for i in range(1, num_chunks + 1):
        cdir = os.path.join(output_dir, f"chunk_{i}")
        os.makedirs(cdir, exist_ok=True)
        chunk_dirs.append(cdir)

        # Copiar metadata si existe
        for meta in ["queryTaxo.tsv", "filterTaxon.dist"]:
            meta_path = os.path.join(input_dir, meta)
            if os.path.exists(meta_path):
                shutil.copy2(meta_path, os.path.join(cdir, meta))

    # Lectura y partición
    if is_paired:
        f1_in = open_fastq(r1_file, "rt")
        f2_in = open_fastq(r2_file, "rt")

        for chunk_idx, target_reads in enumerate(chunk_sizes, 1):
            cdir = chunk_dirs[chunk_idx - 1]
            out1_path = os.path.join(cdir, "queryReads1.fq")
            out2_path = os.path.join(cdir, "queryReads2.fq")

            with open(out1_path, "w") as out1, open(out2_path, "w") as out2:
                for _ in range(target_reads):
                    # 4 líneas por lectura R1
                    l1 = f1_in.readline()
                    l2 = f1_in.readline()
                    l3 = f1_in.readline()
                    l4 = f1_in.readline()
                    out1.write(l1 + l2 + l3 + l4)

                    # 4 líneas por lectura R2
                    r1 = f2_in.readline()
                    r2 = f2_in.readline()
                    r3 = f2_in.readline()
                    r4 = f2_in.readline()
                    out2.write(r1 + r2 + r3 + r4)

            print(f"    [+] Chunk {chunk_idx}: {target_reads:,} pares guardados en {cdir}")

        f1_in.close()
        f2_in.close()
    else:
        f_in = open_fastq(se_file, "rt")
        for chunk_idx, target_reads in enumerate(chunk_sizes, 1):
            cdir = chunk_dirs[chunk_idx - 1]
            out_path = os.path.join(cdir, "queryReads.fq")

            with open(out_path, "w") as out_f:
                for _ in range(target_reads):
                    l1 = f_in.readline()
                    l2 = f_in.readline()
                    l3 = f_in.readline()
                    l4 = f_in.readline()
                    out_f.write(l1 + l2 + l3 + l4)

            print(f"    [+] Chunk {chunk_idx}: {target_reads:,} lecturas guardadas en {cdir}")

        f_in.close()

    print(f"[OK] Partición completada con éxito en {output_dir}")

def main():
    parser = argparse.ArgumentParser(description="Divide queryReads FASTQ en 5 chunks balanceados.")
    parser.add_argument("-i", "--input-dir", required=True, help="Directorio con queryReads originales")
    parser.add_argument("-o", "--output-dir", required=True, help="Directorio destino para los 5 chunks")
    parser.add_argument("-n", "--num-chunks", type=int, default=5, help="Número de chunks (defecto: 5)")
    args = parser.parse_args()

    split_fastq(args.input_dir, args.output_dir, args.num_chunks)

if __name__ == "__main__":
    main()
