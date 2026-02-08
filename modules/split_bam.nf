process SPLIT_BAM {

  tag { sample_id }
  label 'cpu'

  container params.container_trq

  input:
  tuple val(sample_id), val(run_dir), val(load_root), val(log_root), val(dup_bam)

  output:
  tuple val(sample_id),
        val(run_dir),
        val(load_root),
        val(log_root),
        val(dup_bam),
        val("split_bams")

  script:
  """
  set -euo pipefail

  mkdir -p "${log_root}/split_bam"
  mkdir -p "${run_dir}/aligned_files/split_bams"
  mkdir -p "${run_dir}/aligned_files"

  cp -f "${dup_bam}" "${run_dir}/aligned_files/demuxed_aligned_dup_marked.bam"

  tranquillyzer split-bam \\
    ${params.split_bam_opts} \\
    --out-dir "${run_dir}/aligned_files/split_bams" \\
    "${run_dir}/aligned_files/demuxed_aligned_dup_marked.bam" \\
    > "${log_root}/split_bam/${sample_id}.log" 2>&1

  rm -rf split_bams
  cp -R "${run_dir}/aligned_files/split_bams" ./split_bams
  test -d split_bams
  """
}