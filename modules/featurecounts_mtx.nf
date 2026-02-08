process FEATURECOUNTS_MTX {

  tag { sample_id }
  label 'subread'

  input:
  tuple val(sample_id), val(run_dir), val(load_root), val(log_root), val(dup_bam), val(split_bams_dir)
  path gtf
  path fc_script

  output:
  tuple val(sample_id),
        val(run_dir),
        val(load_root),
        val(log_root),
        val(dup_bam),
        val(split_bams_dir),
        val("featurecounts")

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

  echo "OK" > featurecounts/.nf_success

  test -d featurecounts
  ls -lah featurecounts >> "${log_root}/featurecounts/${sample_id}.log"
  """
}