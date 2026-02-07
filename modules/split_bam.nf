process SPLIT_BAM {

    tag { sample_id }
    label 'cpu'

    container params.container_trq

    input:
    tuple val(sample_id), val(work_root), path(dup_marked_bam)

    output:
    // Emit the split-bams directory as a staged path
    tuple val(sample_id), val(work_root), path("split_bams")

    script:
    """
    set -euo pipefail

    mkdir -p "${work_root}/logs"
    mkdir -p "${work_root}/results/${sample_id}/aligned_files/split_bams"

    # Ensure input BAM is in expected location if needed
    mkdir -p "${work_root}/results/${sample_id}/aligned_files"
    cp -f "${dup_marked_bam}" "${work_root}/results/${sample_id}/aligned_files/demuxed_aligned_dup_marked.bam"

    tranquillyzer split-bam \\
      ${params.split_bam_opts} \\
      --out-dir "${work_root}/results/${sample_id}/aligned_files/split_bams" \\
      "${work_root}/results/${sample_id}/aligned_files/demuxed_aligned_dup_marked.bam" \\
      > "${work_root}/logs/${sample_id}_split_bam.log" 2>&1

    # Stage the directory as an output artifact
    cp -R "${work_root}/results/${sample_id}/aligned_files/split_bams" ./split_bams
    """
}