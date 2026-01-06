#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    tranquillyzer-nf
    A Nextflow DSL2 pipeline for processing long-read RNA-seq with Tranquillyzer:
    preprocess → read-length QC → annotate → align → duplicate marking

    Planned extensions:
    - feature counts
    - QC metrics & reporting

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { TRANQUILLYZER_PIPELINE } from './workflows/tranquillyzer'
include { PIPELINE_INITIALISATION; PIPELINE_COMPLETION } from './subworkflows/local/utils_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ENTRYPOINT WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    // 1) Initialization / validation / samplesheet parsing
    PIPELINE_INITIALISATION(
        params.outdir,
        params.samplesheet,
        params.reference,
        params.container_trq,
        params.container_subread
    )

    // 2) Main pipeline
    TRANQUILLYZER_PIPELINE(
        PIPELINE_INITIALISATION.out.samplesheet_ch
    )

    // 3) Completion summary (optional)
    PIPELINE_COMPLETION(
        params.outdir,
        TRANQUILLYZER_PIPELINE.out.final_outputs
    )
}