process ANNOTATE_READS {

  tag "${sample_id}"
  label 'gpu'

  input:
  tuple val(sample_id), val(work_dir), path(metadata)

  output:
  tuple val(sample_id), val(work_dir), path(metadata)

  script:
  """
  set -euo pipefail

  mkdir -p "${work_dir}/logs"

  # When no whitelist is supplied, the samplesheet parser stages the
  # assets/NO_WHITELIST sentinel. Run annotate-reads without demux/correction
  # and let the downstream GENERATE_WHITELIST + BARCODE_CORRECT stages produce
  # demuxed reads. When a real whitelist is supplied, do correction + demux here.
  if [ "\$(basename "${metadata}")" = "NO_WHITELIST" ]; then
    tranquillyzer annotate-reads \\
      ${params.annotate_reads_opts} \\
      --seq-order-file "${params.seq_orders_in_container_path}" \\
      --models-dir "${params.models_dir}" \\
      "${work_dir}/results/${sample_id}" \\
      > "${work_dir}/logs/${sample_id}_annotate_reads.log" 2>&1
  else
    tranquillyzer annotate-reads \\
      ${params.annotate_reads_opts} \\
      --seq-order-file "${params.seq_orders_in_container_path}" \\
      --models-dir "${params.models_dir}" \\
      --whitelist-file "${metadata}" \\
      --run-barcode-correction \\
      --run-demux \\
      "${work_dir}/results/${sample_id}" \\
      > "${work_dir}/logs/${sample_id}_annotate_reads.log" 2>&1
  fi
  """
}
