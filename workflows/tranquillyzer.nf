include { PREPROCESS          } from '../modules/preprocess'
include { READ_LENGTH_DIST_QC } from '../modules/read_length_dist_qc'
include { ANNOTATE_READS      } from '../modules/annotate_reads'
include { ALIGN               } from '../modules/align'
include { DEDUP               } from '../modules/dedup'
include { SPLIT_BAM           } from '../modules/split_bam'
include { FEATURECOUNTS_MTX   } from '../modules/featurecounts_mtx'
include { LOAD_RESULTS        } from '../modules/load_results'

workflow TRANQUILLYZER_PIPELINE {

  take:
  run_ch   // (sample_id, raw_dir, work_dir, metadata)

  main:

  preprocessed_ch = PREPROCESS(run_ch)
  qc_ch          = READ_LENGTH_DIST_QC(preprocessed_ch)
  annotated_ch   = ANNOTATE_READS(qc_ch)

  aligned_ch = ALIGN(
    annotated_ch,
    file(params.reference)
  )

  dedup_ch = DEDUP(aligned_ch)

  if( params.split_bam ) {
    split_bam_ch = SPLIT_BAM(dedup_ch)
  } else {
    // Keep tuple shape consistent: (sample_id, work_dir, split_bams_dir_or_null)
    split_bam_ch = dedup_ch.map { sid, wd, dup_bam ->
      tuple(sid, wd, null)
    }
  }

  if( params.featurecounts ) {
    if( !params.split_bam ) {
      exit 1, "ERROR: featurecounts=true requires split_bam=true"
    }
    if( !params.gtf ) {
      exit 1, "ERROR: featurecounts=true requires --gtf"
    }

    featurecounts_ch = FEATURECOUNTS_MTX(
      split_bam_ch,
      file(params.gtf),
      file("${projectDir}/bin/featurecount_mtx.py")
    )
  } else {
    // Keep tuple shape consistent: (sample_id, work_dir, featurecounts_dir_or_null)
    featurecounts_ch = split_bam_ch.map { sid, wd, split_dir ->
      tuple(sid, wd, null)
    }
  }

  /*
   * ETL rearrangement happens only here.
   * LOAD_RESULTS will:
   * - create: outdir/{extract,transform,load,logs,pipeline_info}
   * - optionally move/copy: results + logs into transform/
   * - stage a curated load/ tree
   */
  loaded_ch = LOAD_RESULTS(featurecounts_ch)

  emit:
  final_outputs = loaded_ch
}