nextflow.enable.dsl = 2

/*
 * Utility subworkflows:
 *  - PIPELINE_INITIALISATION: validate inputs + parse samplesheet -> emits run_ch tuples
 *  - PIPELINE_COMPLETION: blocks until final outputs channel closes, then prints summary
 */

workflow PIPELINE_INITIALISATION {

    take:
    outdir
    samplesheet
    reference
    container_trq
    container_subread

    main:

    // Normalize basic paths early
    def outdir_path     = file(outdir)
    def samplesheet_path = file(samplesheet)
    def reference_path  = file(reference)

    // Validate required inputs (fail fast)
    if( !samplesheet )  error "Missing required --samplesheet"
    if( !reference )    error "Missing required --reference"
    if( !outdir )       error "Missing required --outdir"

    if( !samplesheet_path.exists() )
        error "Samplesheet not found: ${samplesheet_path}"

    if( !reference_path.exists() )
        error "Reference FASTA not found: ${reference_path}"

    // Create output dir
    outdir_path.mkdirs()

    log.info "=========================================="
    log.info " Tranquillyzer-NF initialisation"
    log.info "=========================================="
    log.info " samplesheet              : ${samplesheet_path}"
    log.info " outdir                   : ${outdir_path}"
    log.info " reference                : ${reference_path}"
    log.info " Tranquillyzer container  : ${container_trq}"
    log.info " featureCounts container  : ${container_subread}"
    log.info "=========================================="

    // Canonical absolute work root for all samples
    def work_root = outdir_path.toAbsolutePath().toString()

    // Parse samplesheet
    // Expected TSV with header and at least: sample_id, raw_dir, metadata
    samplesheet_ch = Channel
        .fromPath(samplesheet_path.toString(), checkIfExists: true)
        .splitCsv(header: true, sep: '\t')
        .map { row ->
            if( !row.sample_id ) error "Samplesheet missing required column 'sample_id' (or value empty)."
            if( !row.raw_dir )   error "Samplesheet missing required column 'raw_dir' (or value empty) for sample '${row.sample_id}'."
            if( !row.metadata )  error "Samplesheet missing required column 'metadata' (or value empty) for sample '${row.sample_id}'."

            def sample_id = row.sample_id.toString().trim()
            def raw_dir   = file(row.raw_dir.toString().trim())
            def metadata  = file(row.metadata.toString().trim())

            if( !raw_dir.exists() )
                error "raw_dir not found for sample '${sample_id}': ${raw_dir}"

            if( !metadata.exists() )
                error "metadata file not found for sample '${sample_id}': ${metadata}"

            // Emit canonical tuple
            tuple(sample_id, raw_dir, work_root, metadata)
        }
        .ifEmpty {
            error "Samplesheet parsed to 0 rows. Check format and that it is tab-separated with header."
        }

    emit:
    samplesheet_ch
}

workflow PIPELINE_COMPLETION {

    take:
    outdir
    final_outputs

    main:

    def outdir_path = file(outdir)

    if( final_outputs == null ) {
        log.warn "PIPELINE_COMPLETION: final_outputs is null (no outputs were produced)."
        return
    }

    /*
     * IMPORTANT:
     * Force blocking on workflow completion by consuming the output channel.
     * This ensures the 'completed' banner prints only after upstream finishes.
     */
    final_outputs
        .collect()
        .map { outs ->
            log.info "=========================================="
            log.info " Tranquillyzer-NF completed"
            log.info "=========================================="
            log.info " Results in: ${outdir_path}"
            log.info " Outputs emitted: ${outs.size()}"
            log.info "=========================================="
            return outs
        }

    emit:
    final_outputs
}