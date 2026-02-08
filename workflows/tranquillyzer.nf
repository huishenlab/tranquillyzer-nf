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
  run_ch

  main:

  if( !params.reference ) error "Missing required --reference (FASTA)."
  def reference_fa = file(params.reference)
  if( !reference_fa.exists() ) error "Reference FASTA not found: ${reference_fa}"

  def gtf_file = null
  def fc_script = null
  if( params.featurecounts ) {
    if( !params.split_bam ) error "featurecounts=true requires split_bam=true"
    if( !params.gtf ) error "featurecounts=true but --gtf missing"
    gtf_file = file(params.gtf)
    if( !gtf_file.exists() ) error "GTF not found: ${gtf_file}"

    fc_script = file("${projectDir}/bin/featurecount_mtx.py")
    if( !fc_script.exists() ) error "featurecount_mtx.py not found: ${fc_script}"
  }

  preprocessed_ch = PREPROCESS(run_ch)
  qc_ch          = READ_LENGTH_DIST_QC(preprocessed_ch)
  annotated_ch   = ANNOTATE_READS(qc_ch)
  aligned_ch     = ALIGN(annotated_ch, reference_fa)
  dedup_ch       = DEDUP(aligned_ch)

  // split stage (required if featurecounts=true)
  split_ch = params.split_bam ? SPLIT_BAM(dedup_ch) : error("split_bam must be true for this pipeline variant")

  // featurecounts stage
  fc_ch = params.featurecounts ? FEATURECOUNTS_MTX(split_ch, gtf_file, fc_script) : error("featurecounts must be true for this pipeline variant")

  // load
  loaded_ch = LOAD_RESULTS(fc_ch)

  emit:
  final_outputs = loaded_ch
}