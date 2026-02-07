process PREPROCESS {

    tag { sample_id }
    label 'cpu'

    container params.container_trq

    input:
    tuple val(sample_id), path(raw_dir), val(work_root), path(metadata)

    output:
    // Keep passing metadata forward (staged as path)
    tuple val(sample_id), val(work_root), path(metadata)

    script:
    """
    set -euo pipefail

    mkdir -p "${work_root}/results/${sample_id}"
    mkdir -p "${work_root}/logs"

    tranquillyzer preprocess \\
      ${params.preprocess_opts} \\
      "${raw_dir}" \\
      "${work_root}/results/${sample_id}" \\
      > "${work_root}/logs/${sample_id}_preprocess.log" 2>&1
    """
}