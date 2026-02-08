nextflow.enable.dsl = 2

process FEATURECOUNTS_MTX {

  tag "${sample_id}"
  label 'subread'

  // container comes from nextflow.config via label 'subread'
  // container params.container_subread

  input:
  tuple val(sample_id), path(run_dir), path(split_bams_dir), path(log_root)
  path gtf
  path fc_script

  output:
  tuple val(sample_id), path(run_dir), path("featurecounts")

  script:
  """
  set -euo pipefail

  mkdir -p "${log_root}/featurecounts"
  mkdir -p featurecounts

  # Run featureCounts matrix generation into the OUTPUT dir directly
  python "${fc_script}" \\
    --bam-dir "${split_bams_dir}" \\
    --gtf "${gtf}" \\
    --out-dir "featurecounts" \\
    ${params.featurecounts_opts} \\
    > "${log_root}/featurecounts/${sample_id}.log" 2>&1

  # Sentinel ensures Nextflow always detects the directory output
  echo "OK" > featurecounts/.nf_success
  """
}