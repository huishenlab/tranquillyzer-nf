process FEATURECOUNTS_MTX {

    tag "${sample_id}"
    label 'cpu'

    cpus params.featurecounts_threads
    container params.container_trq

    input:
    tuple val(sample_id), path(work_dir)
    path gtf

    output:
    tuple val(sample_id), path(work_dir)

    script:
    def bam_dir = "${work_dir}/aligned_files/split_bams"
    def out_dir = "${work_dir}/aligned_files/featurecounts"

    // Optional featureCounts related extra args
    def extra_opt = (params.featurecounts_extra && params.featurecounts_extra.toString().trim())
                    ? "--extra \"${params.featurecounts_extra}\""
                    : ""

    """
    mkdir -p ${out_dir}

    python featurecount_mtx.py \\
      --bam-dir ${bam_dir} \\
      --gtf ${gtf} \\
      --out-dir ${out_dir} \\
      --threads ${task.cpus} \\
      --batch-size ${params.featurecounts_batch_size} \\
      ${extra_opt} \\
      > ${work_dir}/aligned_files/featurecounts_mtx.log 2>&1
    """
}