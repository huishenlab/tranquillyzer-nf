process DEDUP {

  tag { sample_id }
  label 'cpu'

  container params.container_trq

  input:
  tuple val(sample_id), val(run_dir), val(load_root), val(log_root), val(aligned_bam)

  output:
  tuple val(sample_id), val(run_dir), val(load_root), val(log_root), val("demuxed_aligned_dup_marked.bam")

  script:
  """
  set -euo pipefail

  mkdir -p "${log_root}/dedup"

  mkdir -p "${run_dir}/aligned_files"
  cp -f "${aligned_bam}" "${run_dir}/aligned_files/demuxed_aligned.bam"

  tranquillyzer dedup \\
    ${params.dedup_opts} \\
    "${run_dir}" \\
    > "${log_root}/dedup/${sample_id}.log" 2>&1

  cp -f "${run_dir}/aligned_files/demuxed_aligned_dup_marked.bam" demuxed_aligned_dup_marked.bam
  test -s demuxed_aligned_dup_marked.bam
  """
}