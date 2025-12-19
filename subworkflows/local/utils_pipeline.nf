nextflow.enable.dsl = 2

workflow PIPELINE_INITIALISATION {

    take:
    outdir
    samplesheet
    reference
    seq_order_file

    main:

    // Validate required inputs
    if( !file(samplesheet).exists() )
        exit 1, "ERROR: samplesheet not found: ${samplesheet}"

    if( !file(reference).exists() )
        exit 1, "ERROR: reference FASTA not found: ${reference}"

    // seq_order_file is optional
    if( seq_order_file && seq_order_file.toString().trim() ) {
        if( !file(seq_order_file).exists() )
            exit 1, "ERROR: seq_order_file set but not found: ${seq_order_file}"
    }

    // Make output dir
    file(outdir).mkdirs()

    log.info "=========================================="
    log.info " Tranquillyzer-NF initialisation"
    log.info "=========================================="
    log.info " samplesheet   : ${samplesheet}"
    log.info " outdir        : ${outdir}"
    log.info " reference     : ${reference}"
    log.info " seq_order_file: ${seq_order_file ?: 'not provided, using default'}"
    log.info "=========================================="

    // Parse samplesheet into a channel
    samplesheet_ch = Channel
        .fromPath(samplesheet)
        .splitCsv(header:true, sep:'\t')
        .map { row ->
            tuple(
                row.sample_id,
                file(row.raw_dir),
                file(row.work_dir),
                file(row.metadata)
            )
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