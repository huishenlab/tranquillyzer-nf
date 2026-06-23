process ALIGN {

  tag "${sample_id}"
  label 'cpu'

  input:
  tuple val(sample_id), val(work_dir)
  path reference

  output:
  // keep passing BAM path as a string like before
  tuple val(sample_id), val(work_dir), val("${work_dir}/transform/${sample_id}/aligned_files/demuxed_aligned.bam")

  script:
  """
  set -euo pipefail

  mkdir -p "${work_dir}/transform/logs"

  tranquillyzer align \\
    ${params.align_opts} \\
    "${work_dir}/transform/${sample_id}" \\
    "${reference}" \\
    "${work_dir}/transform/${sample_id}" \\
    > "${work_dir}/transform/logs/${sample_id}_align.log" 2>&1
  """
}