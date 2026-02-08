process ANNOTATE_READS {

  tag { sample_id }
  label 'gpu'

  container params.container_trq

  input:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(metadata)

  output:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root)

  script:
  """
  set -euo pipefail

  mkdir -p "${log_root}/annotate_reads"

  tranquillyzer annotate-reads \\
    ${params.annotate_reads_opts} \\
    "${run_dir}" \\
    "${metadata}" \\
    > "${log_root}/annotate_reads/${sample_id}.log" 2>&1
  """
}