nextflow.enable.dsl = 2

process SPLIT_BAM {

  tag { sample_id }
  label 'cpu'

  container params.container_trq

  input:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(dup_bam)

  output:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(dup_bam), path("split_bams")

  script:
  """
  set -euo pipefail

  mkdir -p "${log_root}/split_bam"
  mkdir -p "${run_dir}/aligned_files/split_bams"

  # Ensure expected location for split-bam if tool expects it
  mkdir -p "${run_dir}/aligned_files"
  cp -f "${dup_bam}" "${run_dir}/aligned_files/demuxed_aligned_dup_marked.bam"

  tranquillyzer split-bam \\
    ${params.split_bam_opts} \\
    --out-dir "${run_dir}/aligned_files/split_bams" \\
    "${run_dir}/aligned_files/demuxed_aligned_dup_marked.bam" \\
    > "${log_root}/split_bam/${sample_id}.log" 2>&1

  cp -R "${run_dir}/aligned_files/split_bams" ./split_bams
  """
}