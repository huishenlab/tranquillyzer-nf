# Tranquillyzer-nf

**Tranquillyzer-nf** is a reproducible **Nextflow DSL2** pipeline for running the **[Tranquillyzer](https://github.com/huishenlab/tranquillyzer.git)** long-read single-cell RNA-seq (scRNA-seq) processing workflow.  
It is designed for **local execution**, **HPC schedulers (e.g. SLURM)**, and **containerized environments** using **Docker** or **Singularity/Apptainer**, with optional **GPU acceleration**.

**Tranquillyzer (TRANscript QUantification In Long reads-anaLYZER)** is a flexible deep-learning framework for structural annotation and demultiplexing of long-read scRNA-seq data. It performs base-level annotation (adapters, barcodes, UMIs, cDNA, polyA/T), supports custom library architectures via model training, and scales to large datasets.

**Preprint**  
*Tranquillyzer: A Flexible Neural Network Framework for Structural Annotation and Demultiplexing of Long-Read Transcriptomes*  
bioRxiv 2025.07.25.666829  
https://doi.org/10.1101/2025.07.25.666829

---

## Pipeline overview

The pipeline orchestrates the Tranquillyzer workflow end-to-end:

- Read preprocessing and binning
- Read-length distribution QC
- Neural-network-based read annotation and demultiplexing
- Alignment and PCR duplicate marking
- Optional splitting of BAMs by cell barcode
- Optional gene-level quantification using **featureCounts (Subread)**

The pipeline follows an **ETL-style architecture**:

- **Extract**: input validation and normalized samplesheet capture  
- **Transform**: per-sample reproducible run directories  
- **Load**: curated, user-facing outputs (BAMs, stats, annotation parquets, count matrices)

This separation improves reproducibility, debuggability, and downstream usability.

---

## Requirements

- **Nextflow** (recommended ≥ 23.x)
- One container runtime:
  - **Docker**, or
  - **Singularity / Apptainer**
- Optional: GPU-capable nodes for accelerated annotation

For HPC usage with GPUs, ensure a compatible CUDA stack is available on the host.

---

## Quick start

### 1) Clone the repository
```bash
git clone https://github.com/AyushSemwal/tranquillyzer-nf.git
cd tranquillyzer-nf
```

---

### 2) Prepare a samplesheet
The samplesheet must be a TSV file with the following columns:
* sample_id
* raw_dir (directory containing raw reads)
* metadata (library / barcode metadata)

### 3) Configure parameters
All execution behavior is controlled through a params config file (no need to switch profiles).

Minimal example:
```groovy
params {
  executor         = 'local'             // 'local' or 'slurm'
  container_engine = 'docker'            // 'docker' | 'singularity' | 'apptainer'
  enable_gpu       = false               // true to enable GPU for GPU-labeled processes
}
```
Additional cluster- or environment-specific settings (optional):
```groovy
params {
  slurm_queue    = 'my-queue'
  slurm_time     = '48h'
  slurm_cpus     = 64
  slurm_gpu_opts = ''                    // e.g. '--gres=gpu:1'
}
```
Optional ETL behavior

```groovy
params {
  cleanup_transform = false            // set true to delete transform outputs after load
}
```

### 4) Run the pipeline

The pipeline can be run **directly from GitHub** (recommended) or from a local clone.

#### Option A: Run directly from GitHub (recommended)
```bash
nextflow run huishenlab/tranquillyzer-nf \
  -c conf/tests/params_10x3p.config \
  --samplesheet path/to/samplesheet.tsv \
  --reference path/to/reference.fa \
  --gtf path/to/annotation.gtf \
  --outdir results/run1 \
  -resume
```
#### Option B: Run from a local clone

```bash
nextflow run . \
  -c conf/tests/params_10x3p.config \
  --samplesheet path/to/samplesheet.tsv \
  --reference path/to/reference.fa \
  --gtf path/to/annotation.gtf \
  --outdir results/run1 \
  -resume
```

## Notes
- No profile explosion: execution mode, container engine, and GPU usage are fully param-driven.
- GPU usage is selective: only processes labeled gpu receive GPU flags.
- featureCounts is always CPU-only and runs in the Subread container.
- Container flags are user-controlled via container_extra_opts.