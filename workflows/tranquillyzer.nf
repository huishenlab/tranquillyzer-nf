nextflow.enable.dsl = 2

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
  // (sample_id, raw_dir, run_dir, load_root, log_root, metadata)
  run_ch

  main:

  if( !params.reference ) error "Missing required --reference (FASTA)."
  def reference_fa = file(params.reference)
  if( !reference_fa.exists() ) error "Reference FASTA not found: ${reference_fa}"

  def gtf_file = null
  def fc_script = null

  if( params.featurecounts ) {
    if( !params.split_bam ) {
      error "featurecounts=true requires split_bam=true (needs split BAM directory)."
    }
    if( !params.gtf ) error "featurecounts=true but --gtf was not provided."
    gtf_file = file(params.gtf)
    if( !gtf_file.exists() ) error "GTF not found: ${gtf_file}"

    fc_script = file("${projectDir}/bin/featurecount_mtx.py")
    if( !fc_script.exists() ) error "featureCounts helper script not found: ${fc_script}"
  }

  preprocessed_ch = PREPROCESS(run_ch)
  qc_ch          = READ_LENGTH_DIST_QC(preprocessed_ch)
  annotated_ch   = ANNOTATE_READS(qc_ch)
  aligned_ch     = ALIGN(annotated_ch, reference_fa)
  dedup_ch       = DEDUP(aligned_ch)

  /*
   * SPLIT_BAM
   * input:  (sid, run_dir, load_root, log_root, dup_bam)
   * output: (sid, run_dir, load_root, log_root, dup_bam, split_bams_dir)
   */
  if( params.split_bam ) {
    split_ch = SPLIT_BAM(dedup_ch)
  } else {
    // if split_bam is disabled, create an empty placeholder dir in the task workdir
    // (featurecounts is already gated behind split_bam=true, so this is mainly for LOAD_RESULTS)
    split_ch = dedup_ch.map { sid, run_dir, load_root, log_root, dup_bam ->
      tuple(sid, run_dir, load_root, log_root, dup_bam, file("."))
    }
  }

  /*
   * FEATURECOUNTS
   * input:  (sid, run_dir, load_root, log_root, dup_bam, split_bams_dir)
   * output: (sid, run_dir, load_root, log_root, dup_bam, split_bams_dir, featurecounts_dir)
   */
  if( params.featurecounts ) {
    fc_ch = FEATURECOUNTS_MTX(split_ch, gtf_file, fc_script)
  } else {
    // add an empty featurecounts placeholder so LOAD_RESULTS always receives 7-tuple
    fc_ch = split_ch.map { sid, run_dir, load_root, log_root, dup_bam, split_bams_dir ->
      tuple(sid, run_dir, load_root, log_root, dup_bam, split_bams_dir, file("."))
    }
  }

  /*
   * LOAD stage
   */
  loaded_ch = LOAD_RESULTS(fc_ch)

  emit:
  final_outputs = loaded_ch
}