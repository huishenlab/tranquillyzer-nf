// workflows/tranquillyzer.nf
nextflow.enable.dsl = 2

include { PREPROCESS          } from '../modules/preprocess'
include { READ_LENGTH_DIST_QC } from '../modules/read_length_dist_qc'
include { ANNOTATE_READS      } from '../modules/annotate_reads'
include { ALIGN               } from '../modules/align'
include { DEDUP               } from '../modules/dedup'
include { SPLIT_BAM           } from '../modules/split_bam'
include { FEATURECOUNTS_MTX   } from '../modules/featurecounts_mtx'

workflow TRANQUILLYZER_PIPELINE {

    take:
    run_ch   // channel emitting (sample_id, raw_dir, work_root, metadata)

    main:

    // Validate required reference once and pass as path
    if( !params.reference ) error "Missing required --reference (FASTA)."
    def reference_fa = file(params.reference)
    if( !reference_fa.exists() ) error "Reference FASTA not found: ${reference_fa}"

    // Optional: featureCounts prerequisites
    def gtf_file = null
    def fc_script = null
    if( params.featurecounts ) {
        if( !params.gtf ) error "featurecounts=true but --gtf was not provided. Provide --gtf <path> or set --featurecounts false."
        gtf_file = file(params.gtf)
        if( !gtf_file.exists() ) error "GTF not found: ${gtf_file}"

        fc_script = file("${projectDir}/bin/featurecount_mtx.py")
        if( !fc_script.exists() ) error "featureCounts helper script not found: ${fc_script}"
    }

    /*
     * Main pipeline
     */
    preprocessed_ch = PREPROCESS(run_ch)

    qc_ch = READ_LENGTH_DIST_QC(preprocessed_ch)

    annotated_ch = ANNOTATE_READS(qc_ch)

    aligned_ch = ALIGN(
        annotated_ch,
        reference_fa
    )

    dedup_ch = DEDUP(aligned_ch)

    if( params.split_bam ) {
        split_bam_ch = SPLIT_BAM(dedup_ch)
    } else {
        split_bam_ch = dedup_ch
    }

    if( params.featurecounts ) {
        featurecounts_ch = FEATURECOUNTS_MTX(
            split_bam_ch,
            gtf_file,
            fc_script
        )
    } else {
        featurecounts_ch = split_bam_ch
    }

    emit:
    final_outputs = featurecounts_ch
}