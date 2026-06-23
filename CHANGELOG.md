# Changelog

All notable changes to this project will be documented in this file.

## [0.3.0] - 2026-04-23
### Breaking
- Now requires Tranquillyzer **≥ 1.0.1**. Container tag bumped to `varishenlab/tranquillyzer:tranquillyzer_v1.0.1_tf2.15.0`.
- Dropped the REG and HYB annotation modes (deprecated upstream). The `--model-type` flag is no longer passed; only CRF-trained models load.
- `annotate-reads` whitelist is now supplied via `--whitelist-file` with explicit `--run-demux` and `--run-barcode-correction` (v1.0.1 made demux and correction opt-in).
- `samplesheet.metadata` is now **optional**; an empty value routes the sample through the new generate-whitelist branch.

### Added
- New optional workflow branch for samples without a pre-supplied whitelist:
  `ANNOTATE_READS → GENERATE_WHITELIST → BARCODE_CORRECT → ALIGN`.
- New `QC_METRICS` step gated by `--qc_metrics true`, producing an HTML QC report under `load/<sample>/reports/qc/`.
- New `READ_SEQ_ORDERS` + `FETCH_MODELS` pre-flight stages that auto-download model bundles into `${baseDir}/models/` on first run, driven by the container-bundled `utils/seq_orders.yaml` registry. Subsequent runs reuse the cache.
- Support for user-trained model bundles via `--custom_model_registries`. Each entry is a `[seq_orders, models_dir]` pair; the pipeline validates the listed files and symlinks each model directory into the consolidated `models_dir` so a single `--models-dir` covers default + user models.
- New params: `qc_metrics`, `qc_metrics_opts`, `generate_whitelist_opts`, `barcode_correct_opts`, `whitelist_filename`, `models_dir`, `model_url_base`, `seq_orders_in_container_path`, `custom_model_registries`, `skip_template_models`, `fetch_models_maxForks`.
- New sentinel `assets/NO_WHITELIST` used by the samplesheet parser when `metadata` is empty.

### Changed
- `FEATURECOUNTS_MTX` now calls the native `tranquillyzer featurecounts` subcommand; the pipeline no longer ships a separate Python wrapper.
- `split_bam_opts` default now pins `--tag CB --filter-duplicates` for self-documentation (matches upstream v1.0.1 defaults).
- `models_dir` default flipped from `null` to `${baseDir}/models` so the auto-fetch cache has a stable home inside the pipeline checkout.

### Removed
- `bin/featurecount_mtx.py` and the whole `bin/` directory.
- `container_subread` parameter and the `withLabel: 'subread'` block in `nextflow.config`.
- `--model-type CRF` from the default `annotate_reads_opts` in both `conf/params.config` and `conf/tests/params_10x3p.config`.

### Notes
- Tranquillyzer v1.0.1 model bundles use `params.yaml` (previously `params.json`) alongside `model.h5` and `lbl_bin.pkl`. The pipeline ships no model files itself, but users who point `--models-dir` at a custom directory must migrate their bundles to the new layout.
- The default model `10x3p_sc_ont_011` is retained. It must contain CRF layers to load under v1.0.1 — REG-only weights will not load. If the first CI run fails to load this model, switch the default to `10x3p_sc_ont_016` via `--annotate_reads_opts`.

## [0.1.0] - 2026-01-24
### Added
- Initial public release of tranquillyzer-nf
- Versioned pipeline execution via Nextflow manifest
- Full capture of merged pipeline parameters for reproducibility

### Changed
- N/A

### Fixed
- N/A
