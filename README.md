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

The pipeline orchestrates the Tranquillyzer **v1.0.1** workflow end-to-end:

- Read preprocessing and binning
- Read-length distribution QC
- Neural-network-based read annotation (optionally with inline barcode correction + demultiplexing when a whitelist is supplied)
- Auto-generation of a barcode whitelist and standalone correction + demultiplexing when no whitelist is provided
- Alignment and PCR duplicate marking
- Optional splitting of BAMs by cell barcode
- Optional gene-level quantification via the native `tranquillyzer featurecounts` subcommand
- Optional QC metrics report via `tranquillyzer qc-metrics`

The pipeline follows an **ETL-style architecture**:

- **Extract**: input validation and normalized samplesheet capture  
- **Transform**: per-sample reproducible run directories  
- **Load**: curated outputs (BAMs, stats, annotation parquets, count matrices, QC reports)

Included steps:
* Read preprocessing and binning
* Read-length distribution QC
* Neural-network-based read annotation and demultiplexing
* Auto-generate whitelist + barcode correction (only when `metadata` is empty in the samplesheet)
* Alignment and PCR duplicate marking
* Optional splitting of BAMs by cell barcode (`--split_bam`)
* Optional gene-level quantification (`--featurecounts`)
* Optional QC metrics report (`--qc_metrics`)

---

### Requirements

- **Nextflow** (recommended ≥ >=25.04.7)
- One container runtime:
  - **Docker**, or
  - **Singularity / Apptainer**
- Optional: GPU-capable nodes for accelerated annotation + compatible CUDA stack on the host (for GPU acceleration)

---

### Repository layout
* **nextflow.config:** Global defaults + profiles (infra + container engine) + reporting.
* **conf/params.config:** Pipeline parameters (inputs, toggles, tool options, containers, throttling).

---

### Inputs

#### <u>Samplesheet (TSV)</u>

Your samplesheet must be a TSV with:
* sample_id (required)
* raw_dir (required; directory containing raw reads)
* metadata (optional; path to a barcode whitelist TSV — leave empty to auto-generate one)

The pipeline expects --samplesheet to point to this TSV.

When the `metadata` column is empty for a row, the pipeline runs
`tranquillyzer annotate-reads` without demux/correction, then
`tranquillyzer generate-whitelist`, then `tranquillyzer barcode-correct`
to produce demuxed reads for the downstream alignment steps.

#### <u>Reference</u>
* --reference (required)
* --gtf (optional; required if --featurecounts true)

### <u>Parameters</u>

All parameters come from conf/params.config (and can be overridden on the CLI or via an additional -c config).

#### <u>Required</u>
*	--samplesheet : path to samplesheet TSV
*	--reference   : reference FASTA (or appropriate reference expected by your aligner wrapper)
*	--outdir      : output directory (default ./results)

#### <u>Optional</u>
* --gtf : annotation GTF (needed for featureCounts)

#### <u>Pipeline toggles</u>
*	--split_bam (default true)
*	--featurecounts (default true)
*	--qc_metrics (default false)
*	--cleanup_transform (default false)

#### <u>Model bundles (auto-download)</u>

Tranquillyzer v1.0.0+ containers no longer ship default model bundles inside
the image. The pipeline handles this automatically:

1. On the first run, `READ_SEQ_ORDERS` reads `/app/utils/seq_orders.yaml` from
   inside the Tranquillyzer container — that's the canonical list of model
   names shipped upstream.
2. `FETCH_MODELS` downloads the bundle archive from `--model_url_base`
   (a Dropbox folder share by default, downloaded once as a zip), filters
   out the `archived/` subdir, and stages the three files per model **flat**
   under `${baseDir}/models/`:
   `<model_name>.h5`, `<model_name>_lbl_bin.pkl`, `<model_name>_params.yaml`.
   That's the layout tranquillyzer's `--models-dir` expects.
3. Every model listed in `skip_template_models` (default `['template']`)
   is excluded.
4. Subsequent runs are no-ops: the cache lives inside the pipeline
   directory and persists across runs.

Relevant params:

* `--models_dir <path>` — where consolidated bundles live. Default
  `${baseDir}/models`. Override to point at a shared HPC cache.
* `--model_url_base <url>` — where to fetch from. Default points at the
  upstream Dropbox folder share; override to mirror to S3 or a local web
  host. (Per-file URLs aren't supported because Dropbox folder shares only
  allow whole-folder zip downloads.)
* `--seq_orders_in_container_path <path>` — absolute path to the registry
  inside the container. Default `/app/utils/seq_orders.yaml` (the upstream
  source tree is COPYed to `/app/`, not pip-installed). Override only if
  upstream relocates it.
* `--skip_template_models '[...]'` — model names to exclude.

If you've trained your own model bundles, register them through
`--custom_model_registries`. Each entry is a `[seq_orders: <host file>,
models_dir: <host dir>]` pair; the pipeline validates the bundles exist on
disk, then symlinks each model directory into the consolidated `models_dir`
so a single `--models-dir` covers everything for the downstream
`annotate-reads` and `barcode-correct` calls. Example:

```nextflow
custom_model_registries = [
  [ seq_orders: '/lab/shared/my_seq_orders.yaml',
    models_dir: '/lab/shared/my_models' ]
]
```

#### <u>Containers</u>

Defaults (from conf/params.config):
*	--container_trq : varishenlab/tranquillyzer:tranquillyzer_v1.0.1_tf2.15.0
*	--image_dir : ${baseDir}/container_images (used as cache dir for Apptainer/Singularity)

The pipeline now runs `featureCounts` via the native
`tranquillyzer featurecounts` subcommand inside the Tranquillyzer
container — no separate subread container is required.

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

#### <u>Throttling / maxForks</u>

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
*	--generate_whitelist_opts
*	--barcode_correct_opts
*	--align_opts
*	--dedup_opts
*	--split_bam_opts
*	--featurecounts_opts
*	--qc_metrics_opts

---

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
nextflow run AyushSemwal/tranquillyzer-nf -r v0.3.0 \
  -profile local,docker \
  --samplesheet path/to/samplesheet.tsv \
  --reference path/to/reference.fa \
  --gtf path/to/annotation.gtf \
  --outdir results/run1 \
  -resume
```

### 2) Local + Apptainer
```bash
nextflow run AyushSemwal/tranquillyzer-nf -r v0.3.0 \
  -profile local,apptainer \
  --samplesheet path/to/samplesheet.tsv \
  --reference path/to/reference.fa \
  --gtf path/to/annotation.gtf \
  --outdir results/run1 \
  -resume
```

### 3) SLURM + Apptainer

```bash
nextflow run AyushSemwal/tranquillyzer-nf -r v0.3.0 \
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
nextflow run AyushSemwal/tranquillyzer-nf -r v0.3.0 \
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
---