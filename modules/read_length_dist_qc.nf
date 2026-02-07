process READ_LENGTH_DIST_QC {

    tag { sample_id }
    label 'cpu'

    container params.container_trq

    input:
    tuple val(sample_id), val(work_root), path(metadata)

    output:
    tuple val(sample_id), val(work_root), path(metadata)

    script:
    """
    set -euo pipefail

    mkdir -p "${work_root}/logs"

    tranquillyzer readlengthdist \\
      "${work_root}/results/${sample_id}" \\
      > "${work_root}/logs/${sample_id}_read_length_dist_qc.log" 2>&1
    """
}