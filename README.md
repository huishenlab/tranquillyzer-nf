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
- **Load**: curated outputs (BAMs, stats, annotation parquets, count matrices)

Included steps:
*	Read preprocessing and binning
* Read-length distribution QC
* Neural-network-based read annotation and demultiplexing
* Alignment and PCR duplicate marking
* Optional splitting of BAMs by cell barcode (--split_bam)
* Optional gene-level quantification using featureCounts (Subread) (--featurecounts)

---

### Requirements

- **Nextflow** (recommended ≥ >=25.04.7)
- One container runtime:
  - **Docker**, or
  - **Singularity / Apptainer**
- Optional: GPU-capable nodes for accelerated annotation + compatible CUDA stack on the host (for GPU acceleration)

### Repository layout
* **nextflow.config:** Global defaults + profiles (infra + container engine) + reporting.
* **conf/params.config:** Pipeline parameters (inputs, toggles, tool options, containers, throttling).

### Inputs

#### Samplesheet (TSV)

Your samplesheet must be a TSV with:
* sample_id
* raw_dir (directory containing raw reads)
* metadata (library/barcode metadata)

The pipeline expects --samplesheet to point to this TSV.

#### Reference
* --reference (required)
* --gtf (optional; required if --featurecounts true)

### Parameters

All parameters come from conf/params.config (and can be overridden on the CLI or via an additional -c config).

#### Required
*	--samplesheet : path to samplesheet TSV
*	--reference   : reference FASTA (or appropriate reference expected by your aligner wrapper)
*	--outdir      : output directory (default ./results)

#### Optional
* --gtf : annotation GTF (needed for featureCounts)

#### Pipeline toggles
*	--split_bam (default true)
*	--featurecounts (default true)
*	--cleanup_transform (default false)

### Containers

Defaults (from conf/params.config):
*	--container_trq : varishenlab/tranquillyzer:tranquillyzer_v0.2.1_tf2.15.0
*	--container_subread : varishenlab/featurecounts:subread2.0.6_py3.10.12
*	--image_dir : ${baseDir}/container_images (used as cache dir for Apptainer/Singularity)

Extra container runtime args:
*	--container_extra_opts : appended to containerOptions (both CPU and GPU)
*	--container_binds : list of bind paths, used to generate --bind ... for Apptainer/Singularity profiles

GPU controls
*	--enable_gpu (default false)
*	--gpus (default 1) used as process.accelerator for withLabel: gpu
*	--slurm_gpu_opts (default '') only applied when using SLURM and GPU is enabled

Optional CUDA library path injection (mostly for Apptainer/Singularity sites):
*	--cuda_lib_dir (default "")
*	populates APPTAINERENV_LD_LIBRARY_PATH and LD_LIBRARY_PATH when set

### Throttling / maxForks

Global executor queue throttle:
*	--queueSize (default 10)

Per-module concurrency limits:
* --preprocess_maxForks
*	--readlengthdist_maxForks
*	--annotate_maxForks
*	--align_maxForks
*	--dedup_maxForks
*	--splitbam_maxForks
*	--featurecounts_maxForks

Tool options (examples)
*	--preprocess_opts
*	--annotate_reads_opts
*	--align_opts
*	--dedup_opts
*	--split_bam_opts
*	--featurecounts_opts

### Profiles

Your nextflow.config uses profiles for:

1. Executor / infrastructure

* local (default behavior)
* slurm
* awsbatch
*	google (Google Life Sciences)
*	azurebatch
*	kubernetes

2. Container engine

* docker
*	apptainer
*	singularity

You can combine profiles with comma-separated lists, e.g. -profile slurm,apptainer.

---

## Quick start

### 1) Local + Docker

```bash
nextflow run AyushSemwal/tranquillyzer-nf -r v0.2.1 \
  -profile local,docker \
  --samplesheet path/to/samplesheet.tsv \
  --reference path/to/reference.fa \
  --gtf path/to/annotation.gtf \
  --outdir results/run1 \
  -resume
```

### 2) Local + Apptainer
```bash
nextflow run AyushSemwal/tranquillyzer-nf -r v0.2.1 \
  -profile local,apptainer \
  --samplesheet path/to/samplesheet.tsv \
  --reference path/to/reference.fa \
  --gtf path/to/annotation.gtf \
  --outdir results/run1 \
  -resume
```

### 3) SLURM + Apptainer

```bash
nextflow run AyushSemwal/tranquillyzer-nf -r v0.2.1 \
  -profile slurm,apptainer \
  --samplesheet path/to/samplesheet.tsv \
  --reference path/to/reference.fa \
  --gtf path/to/annotation.gtf \
  --outdir results/run_slurm \
  --slurm_cpu_queue my-cpu-queue \
  --slurm_gpu_queue my-gpu-queue \
  --slurm_time 48h \
  --slurm_cpus 32 \
  -resume
```

### 4) AWS + Batch + Docker (GPU-enabled for gpu-labeled processes)

```bash
nextflow run AyushSemwal/tranquillyzer-nf -r v0.2.1 \
  -profile awsbatch,docker \
  --samplesheet s3://my-bucket/inputs/samplesheet.tsv \
  --reference  s3://my-bucket/refs/ref.fa \
  --outdir     s3://my-bucket/outputs/trq_gpu_run \
  --workDir    s3://my-bucket/nf-work/trq_gpu_run \
  --aws_region us-east-1 \
  --aws_cpu_queue my-batch-cpu-queue \
  --aws_gpu_queue my-batch-gpu-queue \
  --enable_gpu true \
  --gpus 1 \
  -resume
```
