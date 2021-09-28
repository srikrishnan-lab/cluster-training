#!/bin/bash
# Set SLURM Options
#SBATCH --output=boot_parallel.out
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH -p normal
#SBATCH -t 00:5:00

module load R
Rscript boot_parallel.R