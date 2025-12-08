#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    tranquillyzer-nf: A Nextflow pipeline for processing 
    long-reads single-cell RNA-seq data using tranquillyzer for 
    annotation, barcode correction and duplicate marking.

    Phase 1: preprocess → annotate → align → duplicate marking
    
    Later extensions:
    - feature counts
    - QC metrics
    - multi-sample orchestration

    Github : https://github.com/huishenlab/tranquillyzer.git
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PARAMETERS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params.run_id          = params.run_id          ?: 'run1'
params.raw_dir         = params.raw_dir         ?: './raw_fastq'
params.work_dir        = params.work_dir        ?: './work_tranquillyzer'
params.metadata        = params.metadata        ?: './metadata.txt'
params.reference       = params.reference       ?: './ref/genome.fa'

params.model_name      = params.model_name      ?: 'tranquil_010'
params.model_type      = params.model_type      ?: 'CRF'
params.seq_order_file  = params.seq_order_file  ?: './seq_orders.tsv'
params.chunk_size      = params.chunk_size      ?: 300_000
params.bc_lv_threshold = params.bc_lv_threshold ?: 1
params.gpu_mem         = params.gpu_mem         ?: 48

params.preprocess_cpus = params.preprocess_cpus ?: 32
params.annotate_cpus   = params.annotate_cpus   ?: 32
params.align_cpus      = params.align_cpus      ?: 32
params.dedup_cpus      = params.dedup_cpus      ?: 16

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    container image or SIF; can also be overridden per-profile
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params.container_trq   = params.container_trq   ?: 'varishenlab/tranquillyzer:tranquillyzer_v0.1.1_tf_2.15.1'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Import module processes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PREPROCESS } from './modules/preprocess.nf'
include { READ_LENGTH_DIST_QC } from './modules/read_length_dist_qc.nf'
include { ANNOTATE_READS } from './modules/annotate_reads.nf'
include { ALIGN } from './modules/align.nf'
include { DEDUP } from './modules/dedup.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Channels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

run_ch = Channel
          .fromPath("samplesheet.tsv")
          .splitCsv(header:true)
          .map { row -> tuple(row.sample_id, file(row.raw_dir), file(row.work_dir), file(row.metadata)) }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Workflow definition
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    // 1) Preprocess
    preprocessed_ch = PREPROCESS(run_ch)

    // 2) Read-length distribution QC

    read_length_dist_ch = READ_LENGTH_DIST_QC()
    // 3) Annotate reads (GPU)
    annotated_ch = ANNOTATE_READS(
        preprocessed_ch,
        file(params.metadata),
        file(params.seq_order_file),
        params.model_name,
        params.model_type,
        params.chunk_size,
        params.bc_lv_threshold,
        params.gpu_mem
    )

    // 4) Align
    aligned_ch = ALIGN(
        annotated_ch,
        file(params.reference)
    )

    // 5) Duplicate marking
    dedup_ch = DEDUP(
        aligned_ch
    )

    // Emit final deduplicated BAMs / output dirs
    dedup_ch.view { it -> "DEDUP DONE: ${it}" }
}