process READ_LENGTH_DIST_QC {

    tag "${run_id}"
    label 'cpu'

    container params.container_trq

    input:
    tuple val(run_id), path(work_dir)

    output:
    tuple val(run_id), path(work_dir)

    script:
    """
    mkdir -p ${work_dir}

    tranquillyzer readlengthdist \\
        ${work_dir}
    """
}