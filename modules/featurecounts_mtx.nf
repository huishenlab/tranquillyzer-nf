process FEATURECOUNTS_MTX {

  tag { sample_id }
  label 'subread'

  input:
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(dup_bam), path(split_bams_dir)
  path gtf
  path fc_script

  output:
  // IMPORTANT: output is RELATIVE to task workdir
  tuple val(sample_id),
        path(run_dir),
        path(load_root),
        path(log_root),
        path(dup_bam),
        path(split_bams_dir),
        path("featurecounts", type: 'dir'),
        path("logs/featurecounts.log")

  script:
  """
  set -euo pipefail

  mkdir -p logs
  mkdir -p featurecounts

  python "${fc_script}" \\
    --bam-dir "${split_bams_dir}" \\
    --gtf "${gtf}" \\
    --out-dir "featurecounts" \\
    ${params.featurecounts_opts} \\
    > "logs/featurecounts.log" 2>&1

  # Make sure dir is non-empty so Nextflow always sees it
  echo "OK" > featurecounts/.nf_success
  """
}