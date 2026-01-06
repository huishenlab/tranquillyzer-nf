process ALIGN {

    tag "${sample_id}"
    label 'cpu'

    container params.container_trq

    input:
    tuple val(sample_id), val(work_dir)
    path   reference

    output:
    tuple val(sample_id), val(work_dir), val("${work_dir}/results/${sample_id}/aligned_files/demuxed_aligned.bam")

    script:
    """
    tranquillyzer align \\
        ${params.align_opts} \\
        ${work_dir}/results/${sample_id} \\
        ${reference} \\
        ${work_dir}/results/${sample_id} \\
      > ${work_dir}/logs/${sample_id}_align.log 2>&1
    """
}