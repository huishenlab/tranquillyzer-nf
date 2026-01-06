process FEATURECOUNTS_MTX {

    tag "${sample_id}"
    label 'cpu'

    // cpus params.featurecounts_threads
    container params.container_subread

    input:
    tuple val(sample_id), val(work_dir), val(bam_dir)
    path gtf
    path fc_script

    output:
    tuple val(sample_id), val(work_dir), val("${work_dir}/results/${sample_id}/featurecounts")

    script:
    """
    mkdir -p ${work_dir}/results/${sample_id}/featurecounts

    python ${fc_script} \\
      --bam-dir ${bam_dir} \\
      --gtf ${gtf} \\
      --out-dir ${work_dir}/results/${sample_id}/featurecounts \\
      ${params.featurecounts_opts} \\
      > ${work_dir}/logs/${sample_id}_featurecounts_mtx.log 2>&1
    """
}
