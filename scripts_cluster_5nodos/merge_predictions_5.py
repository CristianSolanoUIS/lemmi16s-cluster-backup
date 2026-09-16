#!/usr/bin/env python3
"""
merge_predictions_5.py
Combina y suma algebraicamente las predicciones parciales (.predictions.tsv)
generadas independientemente por los 5 nodos del cluster.

Reconstituye el resultado exacto sumando la columna 'Size' (conteo de lecturas)
para cada linaje taxonómico ('Taxonomy'), generando el formato oficial LEMMI16s.
"""

import os
import sys
import argparse
from collections import defaultdict

def parse_predictions_file(filepath):
    """
    Lee un archivo de predicciones de LEMMI16s y retorna un diccionario
    con {taxonomy: total_size} y el total de reads del archivo.
    """
    taxa_counts = defaultdict(int)
    total_reads = 0

    if not os.path.exists(filepath):
        print(f"[WARN] Archivo de prediccion no encontrado: {filepath}")
        return taxa_counts, total_reads

    with open(filepath, "r") as f:
        lines = f.readlines()

    header_found = False
    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.startswith("#"):
            continue
        if line.startswith("Group_ID"):
            header_found = True
            continue

        parts = line.split("\t")
        if len(parts) >= 3:
            group_id = parts[0]
            try:
                size = int(parts[1])
            except ValueError:
                continue
            taxonomy = parts[2]

            taxa_counts[taxonomy] += size
            total_reads += size

    return taxa_counts, total_reads

def merge_5_predictions(input_files, output_file):
    print("==================================================")
    print("=== COMBINACION DE PREDICCIONES DE LOS 5 NODOS ===")
    print("==================================================")

    combined_counts = defaultdict(int)
    node_totals = []

    for idx, filepath in enumerate(input_files, 1):
        counts, n_reads = parse_predictions_file(filepath)
        node_totals.append((filepath, n_reads, len(counts)))
        print(f"[*] Nodo/Chunk {idx} ({os.path.basename(filepath)}): {n_reads:,} reads | {len(counts)} taxones")

        for tax, sz in counts.items():
            combined_counts[tax] += sz

    grand_total_reads = sum(combined_counts.values())
    unique_taxa = len(combined_counts)

    print("--------------------------------------------------")
    print(f"[+] Total acumulado (5 nodos): {grand_total_reads:,} reads clasificados")
    print(f"[+] Total de taxones unicos:   {unique_taxa:,}")

    # Ordenar taxones por abundancia descendente
    sorted_taxa = sorted(combined_counts.items(), key=lambda x: x[1], reverse=True)

    # Escribir archivo reconstituido oficial
    os.makedirs(os.path.dirname(os.path.abspath(output_file)), exist_ok=True)
    with open(output_file, "w") as out:
        out.write("#LEMMI16s\n")
        out.write("Group_ID\tSize\tTaxonomy\n")
        for idx, (tax, sz) in enumerate(sorted_taxa):
            out.write(f"group_{idx}\t{sz}\t{tax}\n")

    print(f"[OK] Prediccion final reconstituida guardada en:\n     {output_file}")
    print("==================================================")

def main():
    parser = argparse.ArgumentParser(description="Combina las 5 predicciones de los nodos sumando los conteos de reads.")
    parser.add_argument("-i", "--inputs", nargs="+", required=True, help="Lista de 5 archivos .predictions.tsv")
    parser.add_argument("-o", "--output", required=True, help="Ruta del archivo .predictions.tsv final")
    args = parser.parse_args()

    if len(args.inputs) < 2:
        print(f"[WARN] Se recibieron menos de 2 archivos ({len(args.inputs)}), procediendo de igual forma.")

    merge_5_predictions(args.inputs, args.output)

if __name__ == "__main__":
    main()
