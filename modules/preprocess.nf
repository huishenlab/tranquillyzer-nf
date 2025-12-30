process PREPROCESS {

    tag "${sample_id}"
    label 'cpu'

    cpus params.preprocess_cpus
    container params.container_trq

    input:
    tuple val(sample_id), path(raw_dir), val(work_dir), path(metadata)

    output:
    tuple val(sample_id), val(work_dir), path(metadata)

    script:
    def output_flag = params.output_bquals ? '--output-base-qual' : ''

    """
    mkdir -p ${work_dir}/results/${sample_id}
    mkdir -p ${work_dir}/logs

    tranquillyzer preprocess \\
        ${raw_dir} \\
        ${work_dir}/results/${sample_id} \\
        ${output_flag} \\
        --threads ${task.cpus} \\
      > ${work_dir}/logs/${sample_id}_preprocess.log 2>&1
    """
}
