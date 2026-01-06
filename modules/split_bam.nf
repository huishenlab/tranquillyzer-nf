process SPLIT_BAM {

    tag "${sample_id}"
    label 'cpu'

    container params.container_trq

    input:
    tuple val(sample_id), val(work_dir), val(dup_marked_bam)

    output:
    tuple val(sample_id), val(work_dir), val("${work_dir}/results/${sample_id}/aligned_files/split_bams")

    script:
    """
    mkdir -p ${work_dir}/results/${sample_id}/aligned_files/split_bams

    tranquillyzer split-bam \\
        ${params.split_bam_opts} \\
        --out-dir ${work_dir}/results/${sample_id}/aligned_files/split_bams \\
        ${dup_marked_bam} \\
      > ${work_dir}/logs/${sample_id}_split_bam.log 2>&1
    """
}