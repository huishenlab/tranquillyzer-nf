nextflow.enable.dsl = 2

process FEATURECOUNTS_MTX {

  tag { sample_id }
  label 'cpu'
  label 'subread'

  container params.container_subread

  input:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(dup_bam), path(split_bams_dir)
  path gtf
  path fc_script

  output:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(dup_bam), path(split_bams_dir), path("featurecounts")

  script:
  """
  set -euo pipefail

  mkdir -p "${log_root}/featurecounts"
  mkdir -p "${run_dir}/featurecounts"

  python "${fc_script}" \\
    --bam-dir "${split_bams_dir}" \\
    --gtf "${gtf}" \\
    --out-dir "${run_dir}/featurecounts" \\
    ${params.featurecounts_opts} \\
    > "${log_root}/featurecounts/${sample_id}.log" 2>&1

  cp -R "${run_dir}/featurecounts" ./featurecounts
  """
}