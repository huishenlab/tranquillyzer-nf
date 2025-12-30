process FEATURECOUNTS_MTX {

    tag "${sample_id}"
    label 'cpu'

    cpus params.featurecounts_threads
    container params.container_subread

    input:
    tuple val(sample_id), val(work_dir), val(bam_dir)
    path gtf
    path fc_script

    output:
    tuple val(sample_id), val(work_dir), val("${work_dir}/results/${sample_id}/featurecounts")

    script:
    // Optional featureCounts related extra args
    def extra_opt = (params.featurecounts_extra && params.featurecounts_extra.toString().trim())
                    ? "--extra \"${params.featurecounts_extra}\""
                    : ""

    """
    mkdir -p ${work_dir}/results/${sample_id}/featurecounts

    python ${fc_script} \\
      --bam-dir ${bam_dir} \\
      --gtf ${gtf} \\
      --out-dir ${work_dir}/results/${sample_id}/featurecounts \\
      --threads ${task.cpus} \\
      --batch-size ${params.featurecounts_batch_size} \\
      ${extra_opt} \\
      > ${work_dir}/logs/${sample_id}_featurecounts_mtx.log 2>&1
    """
}
