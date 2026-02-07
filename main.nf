#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { TRANQUILLYZER_PIPELINE } from './workflows/tranquillyzer'
include { PIPELINE_INITIALISATION; PIPELINE_COMPLETION } from './subworkflows/local/utils_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Helpers
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// YAML-safe scalar with basic type preservation
def y(v) {
    if (v == null) return "null"
    if (v instanceof Boolean) return v ? "true" : "false"
    if (v instanceof Number)  return v.toString()

    def s = v.toString()
    s = s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
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

def writeParamsEffective(outdir, params, headerLines=[]) {
    def infoDir = new File("${outdir}/pipeline_info")
    infoDir.mkdirs()

    def f = new File(infoDir, 'params_effective.yml')

    def render
    render = { Map m, int indent = 0 ->
        m.collect { k, v ->
            def pad = '  ' * indent
            if (v instanceof Map) {
                "${pad}${k}:\n" + render(v as Map, indent + 1)
            } else if (v instanceof List) {
                "${pad}${k}:\n" + (v.collect { "${pad}  - ${y(it)}\n" }.join(''))
            } else {
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

def die(msg) {
    log.error(msg)
    System.exit(1)
}

def validateInputs() {
    if (!params.samplesheet) die("Missing required --samplesheet")
    if (!params.reference)  die("Missing required --reference")
    if (!params.outdir)     die("Missing required --outdir")

    def ss = file(params.samplesheet)
    if (!ss.exists()) die("Samplesheet not found: ${params.samplesheet}")

    def ref = file(params.reference)
    if (!ref.exists()) die("Reference not found: ${params.reference}")

    if (params.gtf) {
        def gtf = file(params.gtf)
        if (!gtf.exists()) die("GTF not found: ${params.gtf}")
    }

    def engine = (params.container_engine ?: 'none').toString().toLowerCase()
    def allowed = ['none','docker','singularity','apptainer']
    if (!(engine in allowed)) {
        die("Invalid --container_engine '${params.container_engine}'. Allowed: ${allowed.join(', ')}")
    }

    if (params.enable_gpu == true && engine == 'none') {
        log.warn "enable_gpu=true but container_engine=none. GPU flags won't be applied."
    }
}

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
          --container_engine docker|apptainer|singularity|none
          --version
        """.stripIndent()
        System.exit(0)
    }

    if (params.version) {
        println "tranquillyzer-nf ${pipelineVersion} (revision: ${revision})"
        System.exit(0)
    }

    validateInputs()

    log.info "tranquillyzer-nf ${pipelineVersion} (revision: ${revision}${dirty == true ? ', dirty' : ''})"
    log.info "Run name: ${workflow.runName}"
    log.info "Profile(s): ${workflow.profile ?: 'none'}"
    log.info "Engine: ${params.container_engine ?: 'none'} | GPU: ${params.enable_gpu == true}"
    log.info "Outdir: ${params.outdir}"

    // 1) Initialization / samplesheet parsing
    PIPELINE_INITIALISATION(
        params.outdir,
        params.samplesheet,
        params.reference,
        params.container_trq,
        params.container_subread
    )

    // 2) Write canonical params file
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

    // 3) Main pipeline
    TRANQUILLYZER_PIPELINE(
        PIPELINE_INITIALISATION.out.samplesheet_ch
    )

    // 4) Completion (blocks until final_outputs closes)
    PIPELINE_COMPLETION(
        params.outdir,
        TRANQUILLYZER_PIPELINE.out.final_outputs
    )
}