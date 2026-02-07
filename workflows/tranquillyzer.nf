// workflows/tranquillyzer.nf
nextflow.enable.dsl = 2

include { PREPROCESS          } from '../modules/preprocess'
include { READ_LENGTH_DIST_QC } from '../modules/read_length_dist_qc'
include { ANNOTATE_READS      } from '../modules/annotate_reads'
include { ALIGN               } from '../modules/align'
include { DEDUP               } from '../modules/dedup'
include { SPLIT_BAM           } from '../modules/split_bam'
include { FEATURECOUNTS_MTX   } from '../modules/featurecounts_mtx.nf'

workflow TRANQUILLYZER_PIPELINE {

    take:
    run_ch   // channel emitting (sample_id, raw_dir, work_dir, metadata)

    main:

    /*
     * Fail fast on required inputs (keeps workflow self-contained even if main.nf validates too)
     */
    if( !params.reference ) {
        error "Missing required --reference (FASTA)."
    }
    if( !file(params.reference).exists() ) {
        error "Reference FASTA not found: ${params.reference}"
    }

    /*
     * Main pipeline
     */
    preprocessed_ch = PREPROCESS(run_ch)

    qc_ch = READ_LENGTH_DIST_QC(preprocessed_ch)

    annotated_ch = ANNOTATE_READS(qc_ch)

    aligned_ch = ALIGN(
        annotated_ch,
        file(params.reference)
    )

    dedup_ch = DEDUP(aligned_ch)

    if( params.split_bam ) {
        split_bam_ch = SPLIT_BAM(dedup_ch)
    } else {
        split_bam_ch = dedup_ch
    }

    /*
     * featureCounts matrix generation (optional)
     * - If enabled, require --gtf and validate existence to avoid file(null) crashes.
     */
    if( params.featurecounts ) {

        if( !params.gtf ) {
            error "featurecounts=true but --gtf was not provided. Provide --gtf <path> or set --featurecounts false."
        }
        if( !file(params.gtf).exists() ) {
            error "GTF not found: ${params.gtf}"
        }

        def fc_script = "${projectDir}/bin/featurecount_mtx.py"
        if( !file(fc_script).exists() ) {
            error "featureCounts helper script not found: ${fc_script}"
        }

        featurecounts_ch = FEATURECOUNTS_MTX(
            split_bam_ch,
            file(params.gtf),
            file(fc_script)
        )
    } else {
        featurecounts_ch = split_bam_ch
    }

    final_outputs = featurecounts_ch

    emit:
    final_outputs
}