process ALIGN {

    tag "${sample_id}"
    label 'cpu'

    cpus params.align_cpus
    container params.container_trq

    input:
    tuple val(sample_id), val(work_dir)
    path   reference

    output:
    // Emit BAM path as well as work_dir for downstream processes
    tuple val(sample_id), val(work_dir), val("${work_dir}/results/${sample_id}/aligned_files/demuxed_aligned.bam")

    script:
    """
    tranquillyzer align \\
        ${work_dir}/results/${sample_id} \\
        ${reference} \\
        ${work_dir}/results/${sample_id} \\
        --threads ${task.cpus} \\
      > ${work_dir}/logs/${sample_id}_align.log 2>&1
    """
}