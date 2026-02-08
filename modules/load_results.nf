process LOAD_RESULTS {

  tag { sample_id }
  label 'cpu'

  input:
  tuple val(sample_id),
        val(run_dir),
        val(load_root),
        val(log_root),
        val(dup_bam),
        val(split_bams_dir),
        val(featurecounts_dir)

  output:
  tuple val(sample_id), path("${sample_id}_load_dir")

  script:
  """
  set -euo pipefail

  DEST="${load_root}/${sample_id}"
  mkdir -p "\${DEST}/bam"
  mkdir -p "\${DEST}/reports"

  cp -f "${dup_bam}" "\${DEST}/bam/demuxed_aligned_dup_marked.bam"

  if [ -n "${split_bams_dir}" ] && [ -d "${split_bams_dir}" ]; then
    mkdir -p "\${DEST}/split_bams"
    cp -R "${split_bams_dir}/." "\${DEST}/split_bams/" || true
  fi

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