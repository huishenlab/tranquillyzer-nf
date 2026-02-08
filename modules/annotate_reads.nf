process ANNOTATE_READS {

  tag "${sample_id}"
  label 'gpu'

  input:
  tuple val(sample_id), val(work_dir), path(metadata)

  output:
  tuple val(sample_id), val(work_dir)

  script:
  """
  set -euo pipefail

  mkdir -p "${work_dir}/logs"

  tranquillyzer annotate-reads \\
    ${params.annotate_reads_opts} \\
    "${work_dir}/results/${sample_id}" \\
    "${metadata}" \\
    > "${work_dir}/logs/${sample_id}_annotate_reads.log" 2>&1
  """
}