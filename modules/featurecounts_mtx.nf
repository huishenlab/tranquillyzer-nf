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
  // Emit everything downstream needs, plus a single stable artifact
  tuple val(sample_id),
        path(run_dir),
        path(load_root),
        path(log_root),
        path(dup_bam),
        path(split_bams_dir),
        path("featurecounts.tgz")

  script:
  """
  set -euo pipefail

  mkdir -p "${log_root}/featurecounts"
  rm -rf featurecounts
  mkdir -p featurecounts

  python "${fc_script}" \\
    --bam-dir "${split_bams_dir}" \\
    --gtf "${gtf}" \\
    --out-dir "featurecounts" \\
    ${params.featurecounts_opts} \\
    > "${log_root}/featurecounts/${sample_id}.log" 2>&1

  # CI-safe: create a real, non-hidden file
  echo "OK" > featurecounts/SUCCESS

  # CI-safe: output is a *file* (Nextflow always detects it)
  tar -czf featurecounts.tgz featurecounts

  # Debug breadcrumb (helps if it ever fails again)
  ls -lah
  tar -tzf featurecounts.tgz | head -n 50
  """
}