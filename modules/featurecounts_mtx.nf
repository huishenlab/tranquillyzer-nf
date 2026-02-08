process FEATURECOUNTS_MTX {

  tag "${sample_id}"
  label 'subread'

  input:
  tuple val(sample_id), val(work_dir), val(bam_dir)
  path gtf
  path fc_script

  output:
  tuple val(sample_id), val(work_dir), val("${work_dir}/results/${sample_id}/featurecounts")

  script:
  """
  set -euo pipefail

  mkdir -p "${work_dir}/logs"
  mkdir -p "${work_dir}/results/${sample_id}/featurecounts"

  echo "[debug] bam_dir=${bam_dir}" > "${work_dir}/logs/${sample_id}_featurecounts_mtx.log"
  ls -lah "${bam_dir}" >> "${work_dir}/logs/${sample_id}_featurecounts_mtx.log" 2>&1 || true

  python "${fc_script}" \\
    --bam-dir "${bam_dir}" \\
    --gtf "${gtf}" \\
    --out-dir "${work_dir}/results/${sample_id}/featurecounts" \\
    ${params.featurecounts_opts} \\
    >> "${work_dir}/logs/${sample_id}_featurecounts_mtx.log" 2>&1

  # guard
  test -d "${work_dir}/results/${sample_id}/featurecounts"
  """
}