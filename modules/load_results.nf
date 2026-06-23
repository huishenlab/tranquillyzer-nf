process LOAD_RESULTS {

  tag "${sample_id}"
  label 'host'

  container null

  input:
  tuple val(sample_id), val(work_dir), val(featurecounts_dir)

  output:
  tuple val(sample_id), val("${work_dir}/load/${sample_id}")

  script:
  """
  set -euo pipefail

  # ETL roots (idempotent; safe under -resume)
  mkdir -p "${work_dir}/extract" "${work_dir}/transform" "${work_dir}/load" "${work_dir}/pipeline_info"

  # Reads the LIVE transform working dir directly — no snapshot copy.
  SAMPLE_ROOT="${work_dir}/transform/${sample_id}"
  ALN_DIR="\${SAMPLE_ROOT}/aligned_files"

  # Curated load tree per sample
  DEST="${work_dir}/load/${sample_id}"
  mkdir -p "\${DEST}/bam" "\${DEST}/split_bams" "\${DEST}/featurecounts" \\
           "\${DEST}/annotation_metadata" "\${DEST}/reports" "\${DEST}/tables"

  # 1) Final BAM
  if [ -f "\${ALN_DIR}/demuxed_aligned_dup_marked.bam" ]; then
    cp -f "\${ALN_DIR}/demuxed_aligned_dup_marked.bam" "\${DEST}/bam/"
  fi

  # 2) Split BAMs (per-cell)
  if [ -d "\${ALN_DIR}/split_bams" ]; then
    cp -a "\${ALN_DIR}/split_bams/." "\${DEST}/split_bams/" || true
  fi

  # 3) featurecounts — only the matrix; per-batch intermediates stay in transform/
  FC_SRC=""
  if [ -n "${featurecounts_dir}" ] && [ -f "${featurecounts_dir}/counts_matrix.tsv" ]; then
    FC_SRC="${featurecounts_dir}/counts_matrix.tsv"
  elif [ -f "\${SAMPLE_ROOT}/featurecounts/counts_matrix.tsv" ]; then
    FC_SRC="\${SAMPLE_ROOT}/featurecounts/counts_matrix.tsv"
  fi
  if [ -n "\${FC_SRC}" ]; then
    cp -f "\${FC_SRC}" "\${DEST}/featurecounts/"
  fi

  # 4) Annotation metadata — whole subdir copy. Picks up:
  #    annotations_valid.parquet, annotations_invalid.parquet,
  #    discovered_whitelist.tsv (no-whitelist branch),
  #    barcode_counts.tsv, barcode_discovery_stats.json, barcode_rank_plot.png
  if [ -d "\${SAMPLE_ROOT}/annotation_metadata" ]; then
    cp -a "\${SAMPLE_ROOT}/annotation_metadata/." "\${DEST}/annotation_metadata/" || true
  fi

  # 5) Read-count summary tables (at sample root)
  if [ -f "\${SAMPLE_ROOT}/cellId_readCount.tsv" ]; then
    cp -f "\${SAMPLE_ROOT}/cellId_readCount.tsv" "\${DEST}/tables/"
  fi
  if [ -f "\${SAMPLE_ROOT}/matchType_readCount.tsv" ]; then
    cp -f "\${SAMPLE_ROOT}/matchType_readCount.tsv" "\${DEST}/tables/"
  fi

  # 6) Alignment stats TSV (if produced)
  if [ -f "\${ALN_DIR}/demuxed_aligned_dup_marked_stats.tsv" ]; then
    cp -f "\${ALN_DIR}/demuxed_aligned_dup_marked_stats.tsv" "\${DEST}/tables/"
  fi

  # 7) Plots (tranquillyzer-generated)
  if [ -d "\${SAMPLE_ROOT}/plots" ]; then
    mkdir -p "\${DEST}/reports/plots"
    cp -a "\${SAMPLE_ROOT}/plots/." "\${DEST}/reports/plots/" || true
  fi

  # 8) QC: HTML report + plot_data TSVs together under reports/qc/
  if [ -d "\${SAMPLE_ROOT}/qc" ]; then
    mkdir -p "\${DEST}/reports/qc"
    cp -a "\${SAMPLE_ROOT}/qc/." "\${DEST}/reports/qc/" || true
  fi

  # Stable marker artifact
  echo "\${DEST}" > "\${DEST}/LOAD_PATH.txt"

  # Optional cleanup: drop transform/<sample>/ after load completes.
  # Logs stay under transform/logs/ so debug remains possible.
  if [ "${params.cleanup_transform}" = "true" ]; then
    rm -rf "\${SAMPLE_ROOT}"
  fi
  """
}
