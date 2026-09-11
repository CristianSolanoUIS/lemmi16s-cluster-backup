#!/bin/bash
#SBATCH --job-name=lemmi16s
#SBATCH --account=tg
#SBATCH --partition=partition1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --output=/shared/users/grupo1/slurm_%x-%j.out
#SBATCH --error=/shared/users/grupo1/slurm_%x-%j.err

set -e

echo "=========================================="
echo "LEMMI16s Job started on Slurm cluster"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Date: $(date)"
echo "User: $(whoami)"
echo "=========================================="

source /etc/profile
export LEMMI16s_ROOT=/shared/users/grupo1/lemmi16s
export LEMMI16s_NO_CONTAINER=1
export PATH=/shared/users/grupo1/lemmi16s_env/bin:$PATH
export LD_LIBRARY_PATH=/shared/users/grupo1/lemmi16s_env/lib:$LD_LIBRARY_PATH
export PYTHONPATH=/shared/users/grupo1/lemmi16s_env/lib/python3.10/site-packages:$PYTHONPATH

cd $LEMMI16s_ROOT

echo "Running lemmi16s_analysis with 4 cores..."
bash workflow/scripts/lemmi16s_analysis --cores 4

echo "=========================================="
echo "LEMMI16s Job finished successfully!"
echo "Date: $(date)"
echo "=========================================="
