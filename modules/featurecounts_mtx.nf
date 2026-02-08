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
  tuple val(sample_id), path(run_dir), path(load_root), path(log_root), path(dup_bam), path(split_bams_dir), path("featurecounts")

  script:
  """
  set -euo pipefail

  mkdir -p "${log_root}/featurecounts"
  rm -rf featurecounts featurecounts.tmp
  mkdir -p featurecounts.tmp

  python "${fc_script}" \\
    --bam-dir "${split_bams_dir}" \\
    --gtf "${gtf}" \\
    --out-dir "featurecounts.tmp" \\
    ${params.featurecounts_opts} \\
    > "${log_root}/featurecounts/${sample_id}.log" 2>&1

  # Ensure expected output is present before publishing task outputs.
  test -s featurecounts.tmp/counts_matrix.tsv
  mv featurecounts.tmp featurecounts

  # Sentinel ensures directory is never "empty" and always detectable.
  echo "OK" > featurecounts/.nf_success

  # Lightweight manifest helps CI debugging for output staging issues.
  ls -la featurecounts > "${log_root}/featurecounts/${sample_id}.manifest.txt"
  """
}
