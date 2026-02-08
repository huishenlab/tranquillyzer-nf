nextflow.enable.dsl = 2

process FEATURECOUNTS_MTX {

  tag "${sample_id}"
  label 'subread'

  input:
  // (sid, run_dir, load_root, log_root, dup_bam, split_bams_dir)
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(dup_bam), path(split_bams_dir)
  path gtf
  path fc_script

  output:
  // (sid, run_dir, load_root, log_root, dup_bam, split_bams_dir, featurecounts_dir)
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(dup_bam), path(split_bams_dir), path("featurecounts", type: 'dir')

  script:
  """
  set -euo pipefail

  mkdir -p "${log_root}/featurecounts"
  mkdir -p featurecounts

  python "${fc_script}" \\
    --bam-dir "${split_bams_dir}" \\
    --gtf "${gtf}" \\
    --out-dir "featurecounts" \\
    ${params.featurecounts_opts} \\
    > "${log_root}/featurecounts/${sample_id}.log" 2>&1

  # Sentinel ensures directory is never "empty" and always detectable
  echo "OK" > featurecounts/.nf_success
  """
}