process PREPROCESS {

  tag "${sample_id}"
  label 'cpu'

  input:
  tuple val(sample_id), path(raw_dir), val(work_dir), path(metadata)

  output:
  tuple val(sample_id), val(work_dir), path(metadata)

  script:
  """
  set -euo pipefail

  mkdir -p "${work_dir}/results/${sample_id}"
  mkdir -p "${work_dir}/logs"

  tranquillyzer preprocess \\
    ${params.preprocess_opts} \\
    "${raw_dir}" \\
    "${work_dir}/results/${sample_id}" \\
    > "${work_dir}/logs/${sample_id}_preprocess.log" 2>&1
  """
}