#!/usr/bin/env bash
set -o xtrace
set -e

sample_folder=$1
query=$2
model_path=$3
output_file=$4
aux_parameters=$5


mkdir -p tmp_$sample_folder
cd tmp_$sample_folder
directory=`pwd`

if [ -z ${cpus+x} ]; then cpus=$(nproc);fi

#Tutorial from https://benjjneb.github.io/dada2/tutorial.html
echo "running"

cp $query/queryReads1.fq .
cp $query/queryReads2.fq .

runClassifier.R queryReads_$i.fasta $model_path/reference.fasta $cpus $directory "$aux_parameters"
editResult.py results.txt results.tsv summary_taxonomy.tsv

cp results.tsv  $output_file

