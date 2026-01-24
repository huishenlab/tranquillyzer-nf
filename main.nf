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
    Helpers
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// YAML-safe scalar
def y(v) {
    if (v == null) return "null"
    def s = v.toString()
    s = s.replace("\\", "\\\\").replace("\"", "\\\"")
    s = s.replace("\n", "\\n")
    return "\"${s}\""
}

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

def getGitDirty() {
    try {
        def gitDir = new File("${workflow.projectDir}/.git")
        if (!gitDir.exists()) return null
        def proc = ['bash','-lc','git status --porcelain'].execute(null, new File("${workflow.projectDir}"))
        proc.waitFor()
        if (proc.exitValue() != 0) return null
        return proc.in.text.trim() ? true : false
    }
    catch (Exception e) {
        return null
    }
}

/**
 * Write ONE canonical merged-params file to pipeline_info/params_effective.yml.
 * This includes:
 *   1) A small comment header with run/pipeline provenance (NOT YAML keys)
 *   2) The full resolved params map (post-merge, authoritative)
 */
def writeParamsEffective(outdir, params, headerLines=[]) {
    def infoDir = new File("${outdir}/pipeline_info")
    infoDir.mkdirs()

    def f = new File(infoDir, 'params_effective.yml')

    def render
    render = { Map m, int indent = 0 ->
        m.collect { k, v ->
            def pad = '  ' * indent
            if (v instanceof Map) {
                "${pad}${k}:\n" + render(v, indent + 1)
            } else if (v instanceof List) {
                "${pad}${k}:\n" + v.collect { "${pad}  - ${y(it)}\n" }.join('')
            } else {
                // keep booleans/numbers as strings for safety/consistency in this simple writer
                "${pad}${k}: ${y(v)}\n"
            }
        }.join('')
    }

    def text = ''
    if (headerLines && headerLines.size() > 0) {
        text += headerLines.collect { "# ${it}\n" }.join('')
        text += "\n"
    }
    text += render(params as Map)

    f.text = text
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ENTRYPOINT WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    def pipelineVersion = workflow.manifest.version ?: 'unknown'
    def revision = workflow.revision ?: getGitRevision() ?: 'local'
    def dirty = getGitDirty()
    def startedAt = new Date().format("yyyy-MM-dd'T'HH:mm:ssZ")

    if (params.help) {
        println """
        tranquillyzer-nf ${pipelineVersion} (revision: ${revision})

        Required:
          --samplesheet <path>
          --reference  <path>
          --outdir     <path>

        Common optional:
          --gtf <path>
          --split_bam true|false
          --featurecounts true|false
          --enable_gpu true|false
          --executor slurm|local
          --version
        """.stripIndent()
        System.exit(0)
    }

    if (params.version) {
        println "tranquillyzer-nf ${pipelineVersion} (revision: ${revision})"
        System.exit(0)
    }

    log.info "tranquillyzer-nf ${pipelineVersion} (revision: ${revision}${dirty == true ? ', dirty' : ''})"
    log.info "Run name: ${workflow.runName}"
    log.info "Executor: ${params.executor ?: 'local'} | Engine: ${params.container_engine ?: 'none'} | GPU: ${params.enable_gpu == true}"

    // 1) Initialization / validation / samplesheet parsing
    PIPELINE_INITIALISATION(
        params.outdir,
        params.samplesheet,
        params.reference,
        params.container_trq,
        params.container_subread
    )

    // Write ONE canonical merged params file AFTER init validation
    def headerLines = [
        "pipeline: tranquillyzer-nf",
        "pipeline_version: ${pipelineVersion}",
        "revision: ${revision}",
        "dirty: ${dirty}",
        "run_name: ${workflow.runName}",
        "generated_at: ${startedAt}",
        "nextflow_version: ${workflow.nextflow.version}",
        "command_line: ${workflow.commandLine}"
    ]
    writeParamsEffective(params.outdir, params, headerLines)

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