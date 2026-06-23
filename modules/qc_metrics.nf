process QC_METRICS {

  tag "${sample_id}"
  label 'cpu'

  input:
  tuple val(sample_id), val(work_dir), val(dup_bam), val(featurecounts_dir)
  path gtf

  output:
  tuple val(sample_id), val(work_dir)

  script:
  def counts_flag = (featurecounts_dir ? "--counts-matrix \"${featurecounts_dir}/counts_matrix.tsv\"" : '')
  def gtf_flag    = (gtf ? "--gtf \"${gtf}\"" : '')
  def bam_flag    = (dup_bam ? "--bam \"${dup_bam}\"" : '')
  """
  set -euo pipefail

  mkdir -p "${work_dir}/logs"
  mkdir -p "${work_dir}/results/${sample_id}/qc"

  tranquillyzer qc-metrics \\
    ${params.qc_metrics_opts} \\
    --sample-name "${sample_id}" \\
    --output-dir "${work_dir}/results/${sample_id}/qc" \\
    ${bam_flag} \\
    ${counts_flag} \\
    ${gtf_flag} \\
    "${work_dir}/results/${sample_id}" \\
    > "${work_dir}/logs/${sample_id}_qc_metrics.log" 2>&1
  """
}
