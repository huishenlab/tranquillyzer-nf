process LOAD_RESULTS {

  tag "${sample_id}"
  label 'cpu'

  /*
   * Run on host to avoid container mount surprises when moving files around.
   * If you really want it in a container, you can set container params.container_trq,
   * but host is safer for “mv/cp” across the whole outdir.
   */
  container null

  input:
  tuple val(sample_id), val(work_dir), val(featurecounts_dir)

  output:
  tuple val(sample_id), val("${work_dir}/load/${sample_id}")

  script:
  """
  set -euo pipefail

  # ETL roots
  mkdir -p "${work_dir}/extract"
  mkdir -p "${work_dir}/transform"
  mkdir -p "${work_dir}/load"
  mkdir -p "${work_dir}/pipeline_info"

  # Move (or copy) the "old world" into transform/
  # Keep it idempotent if -resume:
  mkdir -p "${work_dir}/transform/results"
  mkdir -p "${work_dir}/transform/logs"

  # results/
  if [ -d "${work_dir}/results" ]; then
    rsync -a --delete "${work_dir}/results/" "${work_dir}/transform/results/"
  fi

  # logs/
  if [ -d "${work_dir}/logs" ]; then
    rsync -a --delete "${work_dir}/logs/" "${work_dir}/transform/logs/"
  fi

  # Curated load tree per sample
  DEST="${work_dir}/load/${sample_id}"
  mkdir -p "\${DEST}/bam"
  mkdir -p "\${DEST}/reports"
  mkdir -p "\${DEST}/split_bams"
  mkdir -p "\${DEST}/featurecounts"

  # final BAM if present
  if [ -f "${work_dir}/transform/results/${sample_id}/aligned_files/demuxed_aligned_dup_marked.bam" ]; then
    cp -f "${work_dir}/transform/results/${sample_id}/aligned_files/demuxed_aligned_dup_marked.bam" "\${DEST}/bam/"
  fi

  # split bams if present
  if [ -d "${work_dir}/transform/results/${sample_id}/aligned_files/split_bams" ]; then
    rsync -a "${work_dir}/transform/results/${sample_id}/aligned_files/split_bams/" "\${DEST}/split_bams/" || true
  fi

  # featurecounts if enabled/present
  if [ -n "${featurecounts_dir}" ] && [ -d "${featurecounts_dir}" ]; then
    rsync -a "${featurecounts_dir}/" "\${DEST}/featurecounts/" || true
  elif [ -d "${work_dir}/transform/results/${sample_id}/featurecounts" ]; then
    rsync -a "${work_dir}/transform/results/${sample_id}/featurecounts/" "\${DEST}/featurecounts/" || true
  fi

  # Optional plots
  if [ -d "${work_dir}/transform/results/${sample_id}/plots" ]; then
    rsync -a "${work_dir}/transform/results/${sample_id}/plots/" "\${DEST}/reports/plots/" || true
  fi

  # Emit a marker file so Nextflow can track something stable
  echo "\${DEST}" > "\${DEST}/LOAD_PATH.txt"
  """
}