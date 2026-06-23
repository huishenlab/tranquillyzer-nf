process BARCODE_CORRECT {

  tag "${sample_id}"
  label 'gpu'

  input:
  tuple val(sample_id), val(work_dir), val(whitelist_path)

  output:
  tuple val(sample_id), val(work_dir)

  script:
  """
  set -euo pipefail

  mkdir -p "${work_dir}/logs"

  tranquillyzer barcode-correct \\
    ${params.barcode_correct_opts} \\
    --seq-order-file "${params.seq_orders_in_container_path}" \\
    --run-demux \\
    "${work_dir}/results/${sample_id}" \\
    "${whitelist_path}" \\
    > "${work_dir}/logs/${sample_id}_barcode_correct.log" 2>&1
  """
}
