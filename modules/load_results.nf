process LOAD_RESULTS {

  tag { sample_id }
  label 'cpu'

  // You can remove container entirely; this step only does cp/mkdir
  // container params.container_trq

  input:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(dup_bam), path(split_bams_dir), path(featurecounts_dir)

  output:
  tuple val(sample_id), path("${sample_id}_load_dir")

  script:
  """
  set -euo pipefail

  DEST="${load_root}/${sample_id}"
  mkdir -p "\${DEST}/bam"
  mkdir -p "\${DEST}/reports"

  cp -f "${dup_bam}" "\${DEST}/bam/demuxed_aligned_dup_marked.bam"

  # split_bams_dir may be an empty placeholder; only copy if real dir exists
  if [ -n "${split_bams_dir}" ] && [ -d "${split_bams_dir}" ]; then
    mkdir -p "\${DEST}/split_bams"
    cp -R "${split_bams_dir}/." "\${DEST}/split_bams/" || true
  fi

  # featurecounts_dir may be an empty placeholder; only copy if real dir exists
  if [ -n "${featurecounts_dir}" ] && [ -d "${featurecounts_dir}" ]; then
    mkdir -p "\${DEST}/featurecounts"
    cp -R "${featurecounts_dir}/." "\${DEST}/featurecounts/" || true
  fi

  if [ -d "${run_dir}/plots" ]; then
    mkdir -p "\${DEST}/reports/plots"
    cp -R "${run_dir}/plots/." "\${DEST}/reports/plots/" || true
  fi

  mkdir -p "${sample_id}_load_dir"
  printf "%s\\n" "\${DEST}" > "${sample_id}_load_dir/LOAD_PATH.txt"
  """
}