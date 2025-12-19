# Tranquillyzer-nf (Under Construction)

A reproducible Nextflow DSL2 pipeline for running the [Tranquillyzer](https://github.com/huishenlab/tranquillyzer.git) long-read single-cell RNA-seq processing workflow, supporting both Docker and Singularity/Apptainer on HPC (SLURM) and cloud GPU platforms.

Tranquillyzer (TRANscript QUantification In Long reads-anaLYZER), is a flexible, architecture-aware deep learning framework for processing long-read single-cell RNA-seq (scRNA-seq) data. It employs a hybrid neural network architecture and a global, context-aware design that enables the precise identification of structural elements. In addition to supporting established single-cell protocols, Tranquillyzer accommodates custom library formats through rapid, one-time model training on user-defined label schemas. Model training for both established and custom protocols can typically be completed within a few hours on standard GPUs.

For a detailed description of the framework, benchmarking results, and application to real datasets, please refer to the
[preprint](https://www.biorxiv.org/content/10.1101/2025.07.25.666829v1).

# Citation

### bioRxiv

```
Tranquillyzer: A Flexible Neural Network Framework for Structural Annotation and
Demultiplexing of Long-Read Transcriptomes. Ayush Semwal, Jacob Morrison, Ian
Beddows, Theron Palmer, Mary F. Majewski, H. Josh Jang, Benjamin K. Johnson, Hui
Shen. bioRxiv 2025.07.25.666829; doi: https://doi.org/10.1101/2025.07.25.666829.
```

# Pipeline

Current pipeline will include:
 - Preprocessing
 - Read-length distribution plotting
 - Read-annotation and demultiplexing
 - PCR-duplicate marking

Intended extensions:
 - Generation and visualization of QC metrics
 - Generation of feature-count matrix 