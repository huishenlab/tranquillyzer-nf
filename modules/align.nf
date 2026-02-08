process ALIGN {

  tag { sample_id }
  label 'cpu'

  container params.container_trq

  input:
  tuple val(sample_id), val(run_dir), val(load_root), val(log_root)
  path reference

  output:
  tuple val(sample_id), val(run_dir), val(load_root), val(log_root), val("demuxed_aligned.bam")

  script:
  """
  set -euo pipefail

  mkdir -p "${log_root}/align"

  tranquillyzer align \\
    ${params.align_opts} \\
    "${run_dir}" \\
    "${reference}" \\
    "${run_dir}" \\
    > "${log_root}/align/${sample_id}.log" 2>&1

  cp -f "${run_dir}/aligned_files/demuxed_aligned.bam" demuxed_aligned.bam
  test -s demuxed_aligned.bam
  """
}