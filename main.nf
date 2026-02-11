#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { TRANQUILLYZER_PIPELINE } from './workflows/tranquillyzer'
include { PIPELINE_INITIALISATION; PIPELINE_COMPLETION } from './subworkflows/local/utils_pipeline'
include { validateInputs; writeParamsEffectiveJson; getGitRevision; getGitDirty } from './lib/utils.groovy'

workflow {

  main:

  def pipelineVersion = workflow.manifest.version ?: 'unknown'
  def revision = workflow.revision ?: getGitRevision(workflow.projectDir) ?: 'local'
  def dirty = getGitDirty(workflow.projectDir)
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

  validateInputs(params)

  def containerEngine = params.container_engine ?: 'none'
  log.info "tranquillyzer-nf ${pipelineVersion} (revision: ${revision}${dirty == true ? ', dirty' : ''})"
  log.info "Run name: ${workflow.runName}"
  log.info "Profile(s): ${workflow.profile ?: 'none'}"
  log.info "Engine: ${containerEngine} | GPU: ${params.enable_gpu == true}"
  log.info "Outdir: ${params.outdir}"

  // 1) Init / extract / parse
  PIPELINE_INITIALISATION(
    params.outdir,
    params.samplesheet,
    params.reference,
    params.container_trq,
    params.container_subread
  )

  // 2) Provenance (JSON)
  def meta = [
    pipeline         : "tranquillyzer-nf",
    pipeline_version : pipelineVersion,
    revision         : revision,
    dirty            : dirty,
    run_name         : workflow.runName,
    generated_at     : startedAt,
    nextflow_version : workflow.nextflow.version,
    command_line     : workflow.commandLine,
    profile          : (workflow.profile ?: 'none'),
    container_engine : containerEngine,
    enable_gpu       : (params.enable_gpu == true)
  ]

  writeParamsEffectiveJson(params.outdir, params, meta)

  // 3) Transform + Load
  TRANQUILLYZER_PIPELINE(
    PIPELINE_INITIALISATION.out.samplesheet_ch
  )

  // 4) Completion (blocks until outputs close)
  PIPELINE_COMPLETION(
    params.outdir,
    TRANQUILLYZER_PIPELINE.out.final_outputs
  )
}