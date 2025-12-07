# Tranquillyzer-nf (Under Construction)

A reproducible Nextflow DSL2 pipeline for running the Tranquillyzer long-read single-cell RNA-seq processing workflow, supporting both Docker and Singularity/Apptainer on HPC (SLURM) and cloud GPU platforms.

Current pipeline will include:
 - Preprocessing
 - Read-length distribution plotting
 - Read-annotation and demultiplexing
 - PCR-duplicate marking

Intended extensions:
 - Generation and visualization of QC metrics
 - Generation of feature-count matrix 