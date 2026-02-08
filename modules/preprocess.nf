process PREPROCESS {

  tag { sample_id }
  label 'cpu'

  container params.container_trq

  input:
  tuple val(sample_id), path(raw_dir), path(run_dir), path(load_root), path(log_root), path(metadata)

  output:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(metadata)

  script:
  """
  set -euo pipefail

  mkdir -p "${run_dir}"
  mkdir -p "${log_root}/preprocess"

  tranquillyzer preprocess \\
    ${params.preprocess_opts} \\
    "${raw_dir}" \\
    "${run_dir}" \\
    > "${log_root}/preprocess/${sample_id}.log" 2>&1
  """
}