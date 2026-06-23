process GENERATE_WHITELIST {

  tag "${sample_id}"
  label 'cpu'

  input:
  tuple val(sample_id), val(work_dir)

  output:
  tuple val(sample_id), val(work_dir), val("${work_dir}/results/${sample_id}/annotation_metadata/${params.whitelist_filename}")

  script:
  """
  set -euo pipefail

  mkdir -p "${work_dir}/logs"

  tranquillyzer generate-whitelist \\
    ${params.generate_whitelist_opts} \\
    --seq-order-file "${params.seq_orders_in_container_path}" \\
    "${work_dir}/results/${sample_id}" \\
    > "${work_dir}/logs/${sample_id}_generate_whitelist.log" 2>&1

  # Guard: the whitelist file must exist for BARCODE_CORRECT to consume it.
  # Upstream writes it to <output_dir>/annotation_metadata/<whitelist_filename>;
  # override --whitelist_filename if the upstream default changes.
  WL_PATH="${work_dir}/results/${sample_id}/annotation_metadata/${params.whitelist_filename}"
  if [ ! -f "\${WL_PATH}" ]; then
    echo "ERROR: generate-whitelist did not produce \${WL_PATH}" >&2
    ls -lah "${work_dir}/results/${sample_id}/annotation_metadata" >&2 || true
    exit 1
  fi
  """
}
