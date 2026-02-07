process ALIGN {

    tag { sample_id }
    label 'cpu'

    container params.container_trq

    input:
    tuple val(sample_id), val(work_root)
    path  reference

    output:
    // Emit BAM as a staged path so downstream can use it safely
    tuple val(sample_id), val(work_root), path("demuxed_aligned.bam")

    script:
    """
    set -euo pipefail

    mkdir -p "${work_root}/logs"

    tranquillyzer align \\
      ${params.align_opts} \\
      "${work_root}/results/${sample_id}" \\
      "${reference}" \\
      "${work_root}/results/${sample_id}" \\
      > "${work_root}/logs/${sample_id}_align.log" 2>&1

    # Expose expected BAM as a staged output
    cp -f "${work_root}/results/${sample_id}/aligned_files/demuxed_aligned.bam" demuxed_aligned.bam
    """
}