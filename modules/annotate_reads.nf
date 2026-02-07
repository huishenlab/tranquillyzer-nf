process ANNOTATE_READS {

    tag { sample_id }
    label 'gpu'

    container params.container_trq

    input:
    tuple val(sample_id), val(work_root), path(metadata)

    output:
    tuple val(sample_id), val(work_root)

    script:
    """
    set -euo pipefail

    mkdir -p "${work_root}/logs"

    tranquillyzer annotate-reads \\
      ${params.annotate_reads_opts} \\
      "${work_root}/results/${sample_id}" \\
      "${metadata}" \\
      > "${work_root}/logs/${sample_id}_annotate_reads.log" 2>&1
    """
}