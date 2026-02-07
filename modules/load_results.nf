nextflow.enable.dsl = 2

process LOAD_RESULTS {

  tag { sample_id }
  label 'host'   // run on host (no container) so we can see real filesystem paths

  input:
  // Always present:
  tuple val(sample_id),
        path(run_dir),
        path(load_root),
        path(log_root),
        path(dup_bam),
        val(split_bams_dir_str),
        val(featurecounts_dir_str)

  output:
  tuple val(sample_id), path("${sample_id}_load_dir")

  script:
  """
  set -euo pipefail

  DEST="${load_root}/${sample_id}"
  mkdir -p "\${DEST}/bam"
  mkdir -p "\${DEST}/reports"
  mkdir -p "\${DEST}/annotations"

  # -------------------------
  # LOAD: final BAM
  # -------------------------
  cp -f "${dup_bam}" "\${DEST}/bam/demuxed_aligned_dup_marked.bam"

  # -------------------------
  # LOAD: dedup stats TSV (optional but expected)
  # Path (per your note): run_dir/aligned_files/demuxed_aligned_dup_marked_stats.tsv
  # -------------------------
  if [ -f "${run_dir}/aligned_files/demuxed_aligned_dup_marked_stats.tsv" ]; then
    cp -f "${run_dir}/aligned_files/demuxed_aligned_dup_marked_stats.tsv" "\${DEST}/bam/demuxed_aligned_dup_marked_stats.tsv"
  else
    echo "WARN: stats file not found at ${run_dir}/aligned_files/demuxed_aligned_dup_marked_stats.tsv" >&2
  fi

  # -------------------------
  # LOAD: split BAMs (optional)
  # -------------------------
  if [ -n "${split_bams_dir_str}" ] && [ -d "${split_bams_dir_str}" ]; then
    mkdir -p "\${DEST}/split_bams"
    cp -R "${split_bams_dir_str}/." "\${DEST}/split_bams/" || true
  fi

  # -------------------------
  # LOAD: featureCounts (optional)
  # -------------------------
  if [ -n "${featurecounts_dir_str}" ] && [ -d "${featurecounts_dir_str}" ]; then
    mkdir -p "\${DEST}/featurecounts"
    cp -R "${featurecounts_dir_str}/." "\${DEST}/featurecounts/" || true
  fi

  # -------------------------
  # LOAD: annotation parquets
  # Your files typically exist under run_dir or run_dir/results/...
  # Try direct paths first, then fallback to find.
  # -------------------------
  copied_any=0

  for f in annotations_valid.parquet annotations_invalid.parquet; do
    if [ -f "${run_dir}/\$f" ]; then
      cp -f "${run_dir}/\$f" "\${DEST}/annotations/\$f"
      copied_any=1
      continue
    fi

    p=\$(find "${run_dir}" -type f -name "\$f" 2>/dev/null | head -n 1 || true)
    if [ -n "\$p" ] && [ -f "\$p" ]; then
      cp -f "\$p" "\${DEST}/annotations/\$f"
      copied_any=1
    fi
  done

  if [ "\$copied_any" -eq 0 ]; then
    echo "WARN: No annotation parquet files found under ${run_dir}" >&2
    echo "INFO: Listing top-level of run_dir for debugging:" >&2
    ls -la "${run_dir}" >&2 || true
  fi

  # -------------------------
  # LOAD: plots (optional)
  # -------------------------
  if [ -d "${run_dir}/plots" ]; then
    mkdir -p "\${DEST}/reports/plots"
    cp -R "${run_dir}/plots/." "\${DEST}/reports/plots/" || true
  fi

  # -------------------------
  # Optional cleanup: remove copied deliverables from TRANSFORM
  # -------------------------
  if [[ "${params.cleanup_transform}" == "true" ]]; then
    echo "cleanup_transform=true: removing loaded deliverables from transform (run_dir=${run_dir})" >&2

    # final BAM(s)
    rm -f "${run_dir}/aligned_files/demuxed_aligned_dup_marked.bam" 2>/dev/null || true
    rm -f "${run_dir}/aligned_files/demuxed_aligned_dup_marked.bam.bai" 2>/dev/null || true

    # dedup stats
    rm -f "${run_dir}/aligned_files/demuxed_aligned_dup_marked_stats.tsv" 2>/dev/null || true

    # split bams
    rm -rf "${run_dir}/aligned_files/split_bams" 2>/dev/null || true

    # featurecounts
    rm -rf "${run_dir}/featurecounts" 2>/dev/null || true

    # annotation parquets (direct)
    rm -f "${run_dir}/annotations_valid.parquet" "${run_dir}/annotations_invalid.parquet" 2>/dev/null || true

    # annotation parquets (anywhere under run_dir, just in case)
    for f in annotations_valid.parquet annotations_invalid.parquet; do
      find "${run_dir}" -type f -name "\$f" -exec rm -f {} + 2>/dev/null || true
    done
  fi

  # Emit a staged artifact pointing to the load dir
  mkdir -p "${sample_id}_load_dir"
  printf "%s\\n" "\${DEST}" > "${sample_id}_load_dir/LOAD_PATH.txt"
  """
}