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

    preprocessed_ch = PREPROCESS(run_ch)

    qc_ch = READ_LENGTH_DIST_QC(preprocessed_ch)

    annotated_ch = ANNOTATE_READS(
        qc_ch
    )

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

    if( params.featurecounts ) {
        featurecounts_ch = FEATURECOUNTS_MTX(split_bam_ch, file(params.gtf), file("${projectDir}/bin/featurecount_mtx.py"))
    } else {
        featurecounts_ch = split_bam_ch
    }

    final_outputs = featurecounts_ch

    emit:
    final_outputs
}