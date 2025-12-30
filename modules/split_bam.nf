process SPLIT_BAM {

    tag "${sample_id}"
    label 'cpu'

    cpus {
        Math.max(
            (params.bucket_threads ?: 1) as int,
            (params.merge_threads  ?: 1) as int
        )
    }
    container params.container_trq

    input:
    tuple val(sample_id), val(work_dir), val(dup_marked_bam)
    val    bucket_threads
    val    merge_threads
    val    max_open_cb_writers

    output:
    tuple val(sample_id), val(work_dir), val("${work_dir}/results/${sample_id}/aligned_files/split_bams")

    script:
    """
    mkdir -p ${work_dir}/results/${sample_id}/aligned_files/split_bams
    # Adapt to your actual Tranquillyzer CLI as needed
    tranquillyzer split-bam \\
        ${dup_marked_bam} \\
        --out-dir ${work_dir}/results/${sample_id}/aligned_files/split_bams \\
        --bucket-threads ${bucket_threads} \\
        --merge-threads ${merge_threads} \\
        --max-open-cb-writers ${max_open_cb_writers} \\
      > ${work_dir}/logs/${sample_id}_split_bam.log 2>&1
    """
}