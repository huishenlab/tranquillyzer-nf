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

  # ETL roots
  mkdir -p "${work_dir}/extract" "${work_dir}/transform" "${work_dir}/load" "${work_dir}/pipeline_info"
  mkdir -p "${work_dir}/transform/results" "${work_dir}/transform/logs"

  # Mirror old structure into transform/ (idempotent; safe with -resume)
  if [ -d "${work_dir}/results" ]; then
    rm -rf "${work_dir}/transform/results"
    mkdir -p "${work_dir}/transform/results"
    cp -a "${work_dir}/results/." "${work_dir}/transform/results/"
  fi

  if [ -d "${work_dir}/logs" ]; then
    rm -rf "${work_dir}/transform/logs"
    mkdir -p "${work_dir}/transform/logs"
    cp -a "${work_dir}/logs/." "${work_dir}/transform/logs/"
  fi

  # Curated load tree per sample
  DEST="${work_dir}/load/${sample_id}"
  mkdir -p "\${DEST}/bam" "\${DEST}/reports" "\${DEST}/split_bams" "\${DEST}/featurecounts" "\${DEST}/tables"

  SAMPLE_ROOT="${work_dir}/transform/results/${sample_id}"
  ALN_DIR="\${SAMPLE_ROOT}/aligned_files"

  # 1) Final BAM
  if [ -f "\${ALN_DIR}/demuxed_aligned_dup_marked.bam" ]; then
    cp -f "\${ALN_DIR}/demuxed_aligned_dup_marked.bam" "\${DEST}/bam/"
  fi

  # 2) Split BAMs
  if [ -d "\${ALN_DIR}/split_bams" ]; then
    cp -a "\${ALN_DIR}/split_bams/." "\${DEST}/split_bams/" || true
  fi

  # 3) featurecounts (prefer explicit input dir when provided)
  if [ -n "${featurecounts_dir}" ] && [ -d "${featurecounts_dir}" ]; then
    cp -a "${featurecounts_dir}/." "\${DEST}/featurecounts/" || true
  elif [ -d "\${SAMPLE_ROOT}/featurecounts" ]; then
    cp -a "\${SAMPLE_ROOT}/featurecounts/." "\${DEST}/featurecounts/" || true
  fi

  # 4) Annotation parquet outputs
  if [ -f "\${SAMPLE_ROOT}/annotations_valid.parquet" ]; then
    cp -f "\${SAMPLE_ROOT}/annotations_valid.parquet" "\${DEST}/tables/"
  fi
  if [ -f "\${SAMPLE_ROOT}/annotations_invalid.parquet" ]; then
    cp -f "\${SAMPLE_ROOT}/annotations_invalid.parquet" "\${DEST}/tables/"
  fi

  # 5) Read-count summary tables
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

  # 7) Plots (optional)
  if [ -d "\${SAMPLE_ROOT}/plots" ]; then
    mkdir -p "\${DEST}/reports/plots"
    cp -a "\${SAMPLE_ROOT}/plots/." "\${DEST}/reports/plots/" || true
  fi

  # Stable marker artifact
  echo "\${DEST}" > "\${DEST}/LOAD_PATH.txt"
  """
}