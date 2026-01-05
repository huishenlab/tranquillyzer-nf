process ANNOTATE_READS {

    tag "${sample_id}"
    label 'gpu'

    cpus params.annotate_cpus
    container null

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
    def engine = (params.container_engine ?: 'apptainer').toLowerCase()
    def imageDir = params.image_dir ?: "$baseDir/container_images"
    def sanitize = { String s -> s.replaceAll(/[\/:]/, '-') }
    def trqLocal = "${imageDir}/${sanitize(params.container_trq)}.img"
    
    def image_ref = (engine in ['apptainer','singularity']) ? trqLocal : params.container_trq
    
    def bind_args = (params.container_binds && params.container_binds.size() > 0)
    ? params.container_binds.collect { b -> "--bind ${b}" }.join(" \\\n    ")
    : null
    
    def extra = (params.container_extra_opts && params.container_extra_opts.toString().trim())
    ? params.container_extra_opts.toString().trim()
    : null
    
    def gpu_flags = (params.container_gpu_flags && params.container_gpu_flags.toString().trim())
    ? params.container_gpu_flags.toString().trim()
    : (engine in ['apptainer','singularity'] ? '--nv' : '--gpus all')
    
    if( engine in ['apptainer','singularity'] && !image_ref )
    throw new IllegalArgumentException("Set params.container_trq_sif (local) or params.container_trq_uri (docker://...) for ${engine}")
    
    def runner
    if( engine == 'apptainer' ) {
      runner = ["apptainer exec", gpu_flags, bind_args, extra, image_ref].findAll{ it }.join(" \\\n    ")
    }
    
    else if( engine == 'singularity' ) {
      runner = ["singularity exec", gpu_flags, bind_args, extra, image_ref].findAll{ it }.join(" \\\n    ")
    }
    
    else if( engine == 'docker' ) {
      def vol_args = (params.container_binds && params.container_binds.size() > 0)
      ? params.container_binds.collect { b -> "-v ${b}" }.join(" \\\n    ")
      : null
      runner = ["docker run --rm", gpu_flags, vol_args, extra, image_ref].findAll{ it }.join(" \\\n    ")
    }
    
    else {
      throw new IllegalArgumentException("Unsupported params.container_engine='${params.container_engine}'")
    }

    """
    ${runner} \\
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