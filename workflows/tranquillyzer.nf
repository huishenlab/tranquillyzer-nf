include { PREPROCESS          } from '../modules/preprocess'
include { READ_LENGTH_DIST_QC } from '../modules/read_length_dist_qc'
include { ANNOTATE_READS      } from '../modules/annotate_reads'
include { ALIGN               } from '../modules/align'
include { DEDUP               } from '../modules/dedup'
include { SPLIT_BAM           } from '../modules/split_bam'
include { FEATURECOUNTS_MTX   } from '../modules/featurecounts_mtx'
include { LOAD_RESULTS        } from '../modules/load_results.nf'

workflow TRANQUILLYZER_PIPELINE {

  take:
  run_ch  // (sample_id, raw_dir, run_dir, load_root, log_root, metadata)

  main:

  // Validate required reference
  if( !params.reference ) error "Missing required --reference (FASTA)."
  def reference_fa = file(params.reference)
  if( !reference_fa.exists() ) error "Reference FASTA not found: ${reference_fa}"

  // featureCounts prerequisites
  def gtf_file = null
  def fc_script = null
  if( params.featurecounts ) {

    // Keep logic simple/robust: featurecounts requires split_bam output directory
    if( !params.split_bam ) {
      error "featurecounts=true requires split_bam=true (needs a BAM directory). Set --split_bam true or --featurecounts false."
    }

    if( !params.gtf ) error "featurecounts=true but --gtf was not provided."
    gtf_file = file(params.gtf)
    if( !gtf_file.exists() ) error "GTF not found: ${gtf_file}"

    fc_script = file("${projectDir}/bin/featurecount_mtx.py")
    if( !fc_script.exists() ) error "featureCounts helper script not found: ${fc_script}"
  }

  // Transform steps
  preprocessed_ch = PREPROCESS(run_ch)
  qc_ch          = READ_LENGTH_DIST_QC(preprocessed_ch)
  annotated_ch   = ANNOTATE_READS(qc_ch)
  aligned_ch     = ALIGN(annotated_ch, reference_fa)
  dedup_ch       = DEDUP(aligned_ch)

  if( params.split_bam ) {
    split_bam_ch = SPLIT_BAM(dedup_ch)
  } else {
    // pass-through for load (no split dir)
    split_bam_ch = dedup_ch.map { sid, run_dir, load_root, log_root, dup_bam ->
      tuple(sid, run_dir, load_root, log_root, dup_bam, null)
    }
  }

  if( params.featurecounts ) {
    featurecounts_ch = FEATURECOUNTS_MTX(split_bam_ch, gtf_file, fc_script)
  } else {
    // pass-through for load (no featurecounts dir)
    featurecounts_ch = split_bam_ch.map { sid, run_dir, load_root, log_root, dup_bam, split_dir ->
      tuple(sid, run_dir, load_root, log_root, dup_bam, split_dir, null)
    }
  }

  // Load step (curate deliverables)
  loaded_ch = LOAD_RESULTS(featurecounts_ch)

  emit:
  final_outputs = loaded_ch
}