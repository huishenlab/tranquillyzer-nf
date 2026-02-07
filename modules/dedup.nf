process DEDUP {

    tag { sample_id }
    label 'cpu'

    container params.container_trq

    input:
    tuple val(sample_id), val(work_root), path(bam)

    output:
    tuple val(sample_id), val(work_root), path("demuxed_aligned_dup_marked.bam")

    script:
    """
    set -euo pipefail

    mkdir -p "${work_root}/logs"

    # Ensure BAM is where tranquillyzer expects it (work_root/results/<sample>/aligned_files/)
    mkdir -p "${work_root}/results/${sample_id}/aligned_files"
    cp -f "${bam}" "${work_root}/results/${sample_id}/aligned_files/demuxed_aligned.bam"

    tranquillyzer dedup \\
      ${params.dedup_opts} \\
      "${work_root}/results/${sample_id}" \\
      > "${work_root}/logs/${sample_id}_dedup.log" 2>&1

    cp -f "${work_root}/results/${sample_id}/aligned_files/demuxed_aligned_dup_marked.bam" demuxed_aligned_dup_marked.bam
    """
}