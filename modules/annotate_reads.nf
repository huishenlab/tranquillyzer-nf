process ANNOTATE_READS {

    tag "${sample_id}"
    label 'gpu'

    cpus params.annotate_cpus
    container params.container_trq

    input:
    tuple val(sample_id), val(work_dir), path(metadata)
    val    model_name
    val    model_type
    val    chunk_size
    val    bc_lv_threshold
    val    gpu_mem

    output:
    tuple val(sample_id), val(work_dir)

    script:
    
    def output_fmt = params.output_fastq ? 'fastq' : 'fasta'

    def seq_order_opt  = (params.seq_order_file && params.seq_order_file.trim()) \
                         ? "--seq-order-file ${params.seq_order_file}" \
                         : ""
    """
    tranquillyzer annotate-reads \\
      ${work_dir}/results/${sample_id} \\
      ${metadata} \\
      --model-name ${model_name} \\
      --output-fmt ${output_fmt} \\
      --gpu-mem ${gpu_mem} \\
      --model-type ${model_type} \\
      ${seq_order_opt} \\
      --chunk-size ${chunk_size} \\
      --bc-lv-threshold ${bc_lv_threshold} \\
      --threads ${task.cpus} \\
    > ${work_dir}/logs/${sample_id}_annotate_reads.log 2>&1
    """
}