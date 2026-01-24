#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    tranquillyzer-nf
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { TRANQUILLYZER_PIPELINE } from './workflows/tranquillyzer'
include { PIPELINE_INITIALISATION; PIPELINE_COMPLETION } from './subworkflows/local/utils_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ENTRYPOINT WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def getGitRevision() {
    try {
        def gitDir = new File("${workflow.projectDir}/.git")
        if (!gitDir.exists()) return null
        def proc = ['bash','-lc','git rev-parse --short HEAD'].execute(null, new File("${workflow.projectDir}"))
        proc.waitFor()
        return proc.exitValue() == 0 ? proc.in.text.trim() : null
    }
    catch (Exception e) {
        return null
    }
}

def writeRunMeta(outdir, meta) {
    def infoDir = new File("${outdir}/pipeline_info")
    infoDir.mkdirs()

    def f = new File(infoDir, 'run_meta.yml')
    f.text = meta.collect { k, v ->
        if (v instanceof Map) {
            "${k}:\n" + v.collect { kk, vv -> "  ${kk}: ${vv}\n" }.join('')
        } else {
            "${k}: ${v}\n"
        }
    }.join('')
}

workflow {

    main:

    def pipelineVersion = workflow.manifest.version ?: 'unknown'
    def revision = workflow.revision ?: getGitRevision() ?: 'local'

    if (params.version) {
        println "tranquillyzer-nf ${pipelineVersion} (revision: ${revision})"
        System.exit(0)
    }

    log.info "tranquillyzer-nf ${pipelineVersion} (revision: ${revision})"
    log.info "Executor: ${params.executor ?: 'local'} | Engine: ${params.container_engine ?: 'none'} | GPU: ${params.enable_gpu == true}"

    def runMeta = [
        pipeline: [
            name    : 'tranquillyzer-nf',
            version : pipelineVersion,
            revision: revision
        ],
        execution: [
            nextflow_version: workflow.nextflow.version,
            executor         : params.executor ?: 'local',
            container_engine : params.container_engine ?: 'none',
            enable_gpu       : params.enable_gpu == true,
            launch_dir       : workflow.launchDir
        ],
        containers: [
            tranquillyzer: params.container_trq,
            subread      : params.container_subread
        ],
        inputs: [
            samplesheet: params.samplesheet,
            reference  : params.reference,
            gtf        : params.gtf
        ]
    ]

    if (!params.version) {
        writeRunMeta(params.outdir, runMeta)
    }

    PIPELINE_INITIALISATION(
        params.outdir,
        params.samplesheet,
        params.reference,
        params.container_trq,
        params.container_subread
    )

    TRANQUILLYZER_PIPELINE(
        PIPELINE_INITIALISATION.out.samplesheet_ch
    )

    PIPELINE_COMPLETION(
        params.outdir,
        TRANQUILLYZER_PIPELINE.out.final_outputs
    )
}