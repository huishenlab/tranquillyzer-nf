process READ_LENGTH_DIST_QC {

  tag { sample_id }
  label 'cpu'

  container params.container_trq

  input:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(metadata)

  output:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(metadata)

  script:
  """
  set -euo pipefail

  mkdir -p "${log_root}/read_length_dist_qc"

  tranquillyzer readlengthdist \\
    "${run_dir}" \\
    > "${log_root}/read_length_dist_qc/${sample_id}.log" 2>&1
  """
}