nextflow.enable.dsl = 2

process DEDUP {

  tag { sample_id }
  label 'cpu'

  container params.container_trq

  input:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(aligned_bam)

  output:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path("demuxed_aligned_dup_marked.bam")

  script:
  """
  set -euo pipefail

  mkdir -p "${log_root}/dedup"

  # Ensure expected BAM location for tranquillyzer if it assumes a canonical path
  mkdir -p "${run_dir}/aligned_files"
  cp -f "${aligned_bam}" "${run_dir}/aligned_files/demuxed_aligned.bam"

  tranquillyzer dedup \\
    ${params.dedup_opts} \\
    "${run_dir}" \\
    > "${log_root}/dedup/${sample_id}.log" 2>&1

  cp -f "${run_dir}/aligned_files/demuxed_aligned_dup_marked.bam" demuxed_aligned_dup_marked.bam
  """
}