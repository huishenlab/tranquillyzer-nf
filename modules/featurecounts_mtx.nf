process FEATURECOUNTS_MTX {

  tag "${sample_id}"
  label 'cpu'

  input:
  tuple val(sample_id), val(work_dir), val(bam_dir)
  path gtf

  output:
  tuple val(sample_id), val(work_dir), val("${work_dir}/transform/${sample_id}/featurecounts")

  script:
  """
  set -euo pipefail

  mkdir -p "${work_dir}/transform/logs"
  mkdir -p "${work_dir}/transform/${sample_id}/featurecounts"

  echo "[debug] bam_dir=${bam_dir}" > "${work_dir}/transform/logs/${sample_id}_featurecounts_mtx.log"
  ls -lah "${bam_dir}" >> "${work_dir}/transform/logs/${sample_id}_featurecounts_mtx.log" 2>&1 || true

  tranquillyzer featurecounts \\
    ${params.featurecounts_opts} \\
    "${bam_dir}" \\
    "${gtf}" \\
    "${work_dir}/transform/${sample_id}/featurecounts" \\
    >> "${work_dir}/transform/logs/${sample_id}_featurecounts_mtx.log" 2>&1

  # guard
  test -d "${work_dir}/transform/${sample_id}/featurecounts"
  """
}
