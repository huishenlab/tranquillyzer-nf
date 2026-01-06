nextflow.enable.dsl = 2

workflow PIPELINE_INITIALISATION {

    take:
    outdir
    samplesheet
    reference
    container_trq
    container_subread

    main:

    // Validate required inputs
    if( !file(samplesheet).exists() )
        exit 1, "ERROR: samplesheet not found: ${samplesheet}"

    if( !file(reference).exists() )
        exit 1, "ERROR: reference FASTA not found: ${reference}"

    // Make output dir
    file(outdir).mkdirs()

    log.info "=========================================="
    log.info " Tranquillyzer-NF initialisation"
    log.info "=========================================="
    log.info " samplesheet              : ${samplesheet}"
    log.info " outdir                   : ${outdir}"
    log.info " reference                : ${reference}"
    log.info " Tranquillyzer container  : ${container_trq}"
    log.info " featureCounts container  : ${container_subread}"
    log.info "=========================================="
    
    def work_dir = file(outdir).toAbsolutePath().toString()

    // Parse samplesheet into a channel
    samplesheet_ch = Channel
        .fromPath(samplesheet)
        .splitCsv(header:true, sep:'\t')
        .map { row ->
            def sample_id = row.sample_id
            def raw_dir   = file(row.raw_dir)
            def metadata  = file(row.metadata)

            // force per-sample workdir under outdir
            tuple( sample_id, raw_dir, work_dir, metadata )
        }

    emit:
    samplesheet_ch
}

workflow PIPELINE_COMPLETION {

    take:
    outdir
    final_outputs

    main:

    log.info "=========================================="
    log.info " Tranquillyzer-NF completed"
    log.info "=========================================="
    log.info " Results in: ${outdir}"
    log.info "=========================================="

    emit:
    final_outputs
}