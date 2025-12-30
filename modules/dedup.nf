process DEDUP {

    tag "${sample_id}"
    label 'cpu'

    cpus params.dedup_cpus
    container params.container_trq

    input:
    tuple val(sample_id), val(work_dir), path(bam)

    output:
    tuple val(sample_id), val(work_dir), val("${work_dir}/results/${sample_id}/aligned_files/demuxed_aligned_dup_marked.bam")

    script:
    """
    # Adapt to your actual Tranquillyzer CLI as needed
    tranquillyzer dedup \\
        ${work_dir}/results/${sample_id} \\
        --threads ${task.cpus} \\
      > ${work_dir}/logs/${sample_id}_dedup.log 2>&1
    """
}