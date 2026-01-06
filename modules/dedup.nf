process DEDUP {

    tag "${sample_id}"
    label 'cpu'

    container params.container_trq

    input:
    tuple val(sample_id), val(work_dir), path(bam)

    output:
    tuple val(sample_id), val(work_dir), val("${work_dir}/results/${sample_id}/aligned_files/demuxed_aligned_dup_marked.bam")

    script:
    """
    tranquillyzer dedup \\
        ${params.dedup_opts} \\
        ${work_dir}/results/${sample_id} \\
      > ${work_dir}/logs/${sample_id}_dedup.log 2>&1
    """
}