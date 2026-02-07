process FEATURECOUNTS_MTX {

    tag { sample_id }
    label 'cpu'
    label 'subread'   // lets you target this process cleanly in config if desired

    container params.container_subread

    input:
    tuple val(sample_id), val(work_root), path(bam_dir)
    path gtf
    path fc_script

    output:
    tuple val(sample_id), val(work_root), path("featurecounts")

    script:
    """
    set -euo pipefail

    mkdir -p "${work_root}/logs"
    mkdir -p "${work_root}/results/${sample_id}/featurecounts"

    python "${fc_script}" \\
      --bam-dir "${bam_dir}" \\
      --gtf "${gtf}" \\
      --out-dir "${work_root}/results/${sample_id}/featurecounts" \\
      ${params.featurecounts_opts} \\
      > "${work_root}/logs/${sample_id}_featurecounts_mtx.log" 2>&1

    # Stage outputs
    cp -R "${work_root}/results/${sample_id}/featurecounts" ./featurecounts
    """
}