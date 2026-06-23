process DEDUP {

  tag "${sample_id}"
  label 'cpu'

  input:
  tuple val(sample_id), val(work_dir), val(bam_path)

  output:
  tuple val(sample_id), val(work_dir), val("${work_dir}/transform/${sample_id}/aligned_files/demuxed_aligned_dup_marked.bam")

  script:
  """
  set -euo pipefail

  mkdir -p "${work_dir}/transform/logs"

  tranquillyzer dedup \\
    ${params.dedup_opts} \\
    "${work_dir}/transform/${sample_id}" \\
    > "${work_dir}/transform/logs/${sample_id}_dedup.log" 2>&1
  """
}