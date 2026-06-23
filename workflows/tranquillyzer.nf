include { READ_SEQ_ORDERS     } from '../modules/read_seq_orders'
include { FETCH_MODELS        } from '../modules/fetch_models'
include { PREPROCESS          } from '../modules/preprocess'
include { READ_LENGTH_DIST_QC } from '../modules/read_length_dist_qc'
include { ANNOTATE_READS      } from '../modules/annotate_reads'
include { GENERATE_WHITELIST  } from '../modules/generate_whitelist'
include { BARCODE_CORRECT     } from '../modules/barcode_correct'
include { ALIGN               } from '../modules/align'
include { DEDUP               } from '../modules/dedup'
include { SPLIT_BAM           } from '../modules/split_bam'
include { FEATURECOUNTS_MTX   } from '../modules/featurecounts_mtx'
include { QC_METRICS          } from '../modules/qc_metrics'
include { LOAD_RESULTS        } from '../modules/load_results'

// seq_orders.yaml parser. Accepts:
//   { name1: {...}, name2: {...} }            (flat map, names are top-level keys)
//   { models: { name1: {...}, ... } }         (wrapped under 'models')
//   { models: [ {name: ...}, ... ] }          (list of model objects)
//   [ name1, name2, ... ] or [ {name: ...} ]  (top-level list)
def parseModelNames(yamlFile) {
  def doc = new org.yaml.snakeyaml.Yaml().load(file(yamlFile).text)
  if (doc instanceof Map) {
    if (doc.containsKey('models')) {
      def m = doc.models
      if (m instanceof Map)  return m.keySet().toList().collect { it.toString() }
      if (m instanceof List) return m.collect { (it instanceof Map && it.name) ? it.name.toString() : it.toString() }
    }
    return doc.keySet().toList().collect { it.toString() }
  }
  if (doc instanceof List) {
    return doc.collect { (it instanceof Map && it.name) ? it.name.toString() : it.toString() }
  }
  error "Could not parse model names from ${yamlFile}: unexpected top-level type ${doc?.getClass()}"
}

// Walks every custom_model_registries entry, validates the bundles exist on the
// host, and symlinks each model file into the consolidated models_dir so
// tranquillyzer sees user and default models behind a single --models-dir.
//
// Tranquillyzer's --models-dir convention is FLAT: each model's three files
// live at the top level with the model_name prefix:
//   <dir>/<model>.h5
//   <dir>/<model>_lbl_bin.pkl
//   <dir>/<model>_params.yaml
def consolidateCustomRegistries(consolidated_dir) {
  def consolidated = file(consolidated_dir)
  consolidated.mkdirs()
  def required_suffixes = ['.h5', '_lbl_bin.pkl', '_params.yaml']
  def skip = (params.skip_template_models ?: []) as Set

  (params.custom_model_registries ?: []).each { entry ->
    def yamlPath = file(entry.seq_orders)
    def src_dir  = file(entry.models_dir)
    if (!yamlPath.exists()) error "custom_model_registries: seq_orders not found: ${yamlPath}"
    if (!src_dir.exists())  error "custom_model_registries: models_dir not found: ${src_dir}"

    parseModelNames(yamlPath).findAll { !skip.contains(it) }.each { m ->
      required_suffixes.each { suffix ->
        def fname   = "${m}${suffix}"
        def srcFile = file("${src_dir}/${fname}")
        if (!srcFile.exists()) {
          error "custom_model_registries: missing ${fname} for model '${m}' under ${src_dir} (declared in ${yamlPath})"
        }
        def dst = file("${consolidated}/${fname}")
        if (dst.exists()) {
          try {
            if (java.nio.file.Files.isSymbolicLink(dst.toPath()) &&
                dst.toRealPath() == srcFile.toRealPath()) {
              return  // already linked to the same target
            }
          } catch (Exception ignored) { /* fall through to error */ }
          error "custom_model_registries: ${dst} already exists; refusing to overlay file from ${srcFile}"
        }
        java.nio.file.Files.createSymbolicLink(dst.toPath(), srcFile.toPath())
      }
    }
  }
  return 'ok'
}

workflow TRANQUILLYZER_PIPELINE {

  take:
  run_ch   // (sample_id, raw_dir, work_dir, metadata)

  main:

  /*
   * Model-bundle prep (runs once per pipeline invocation, before per-sample stages).
   *
   * READ_SEQ_ORDERS pulls the canonical registry out of the tranquillyzer container.
   * FETCH_MODELS downloads + extracts the entire bundle archive (Dropbox folder share
   * forces a single-zip download) and validates each expected bundle. Custom registries
   * are consolidated into the same models_dir via host-side symlinks at workflow init.
   *
   * The combined ready signal gates ANNOTATE_READS so per-sample stages can't start
   * until the cache is fully populated.
   */

  // Ensure the host-side models_dir exists before any process tries to bind it.
  // Apptainer errors out if a --bind source path doesn't exist.
  file(params.models_dir).mkdirs()

  seq_orders_ch = READ_SEQ_ORDERS()

  expected_names_ch = seq_orders_ch.map { y ->
    def skip = (params.skip_template_models ?: []) as Set
    parseModelNames(y).findAll { !skip.contains(it) }
  }

  default_ready_ch = FETCH_MODELS(seq_orders_ch, expected_names_ch)

  custom_ready_ch  = Channel.value( consolidateCustomRegistries(params.models_dir) )

  models_ready_ch  = default_ready_ch
    .combine(custom_ready_ch)
    .map { _a, _b -> 'ok' }
    .first()

  // Gate every per-sample lane on models being ready. Drop the appended marker.
  gated_run_ch = run_ch
    .combine(models_ready_ch)
    .map { sid, raw, wd, meta, _ready -> tuple(sid, raw, wd, meta) }

  preprocessed_ch = PREPROCESS(gated_run_ch)
  qc_ch           = READ_LENGTH_DIST_QC(preprocessed_ch)
  annotated_ch    = ANNOTATE_READS(qc_ch)    // (sid, wd, metadata)

  /*
   * Branch on whitelist availability:
   *   - with_wl: annotate-reads already ran correction+demux inline
   *   - no_wl:   metadata was the NO_WHITELIST sentinel; run
   *              generate-whitelist + barcode-correct to produce demuxed reads
   */
  annotated_branched = annotated_ch.branch { sid, wd, meta ->
    with_wl: meta.getName() != 'NO_WHITELIST'
    no_wl:   meta.getName() == 'NO_WHITELIST'
  }

  gen_wl_in_ch = annotated_branched.no_wl.map { sid, wd, meta -> tuple(sid, wd) }
  gen_wl_ch    = GENERATE_WHITELIST(gen_wl_in_ch)
  corrected_ch = BARCODE_CORRECT(gen_wl_ch)  // (sid, wd)

  ready_for_align_ch = annotated_branched.with_wl
    .map { sid, wd, meta -> tuple(sid, wd) }
    .mix(corrected_ch)

  aligned_ch = ALIGN(
    ready_for_align_ch,
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
      file(params.gtf)
    )
  } else {
    // Keep tuple shape consistent: (sample_id, work_dir, featurecounts_dir_or_null)
    featurecounts_ch = split_bam_ch.map { sid, wd, split_dir ->
      tuple(sid, wd, null)
    }
  }

  /*
   * Optional QC step: tranquillyzer qc-metrics consumes the dup-marked BAM,
   * the counts matrix (if featurecounts ran), and the GTF (if supplied).
   */
  if( params.qc_metrics ) {
    qc_input_ch = dedup_ch
      .join(featurecounts_ch.map { sid, wd, fc_dir -> tuple(sid, fc_dir) })
      .map { sid, wd, dup_bam, fc_dir -> tuple(sid, wd, dup_bam, fc_dir) }

    def qc_gtf = params.gtf ? file(params.gtf) : file("${workflow.projectDir}/assets/NO_WHITELIST")
    qc_done_ch = QC_METRICS(qc_input_ch, qc_gtf)  // (sid, wd)

    // Gate LOAD_RESULTS on QC completion so the qc/ subdir is present when we copy.
    load_in_ch = featurecounts_ch
      .join(qc_done_ch.map { sid, wd -> tuple(sid, 'qc-done') })
      .map { sid, wd, fc_dir, _qc -> tuple(sid, wd, fc_dir) }
  } else {
    load_in_ch = featurecounts_ch
  }

  /*
   * Stage curated load/ tree from the live transform/<sample>/. No duplicating
   * snapshots. With --cleanup_transform true, LOAD_RESULTS deletes
   * transform/<sample>/ after the load copy completes (logs preserved).
   */
  loaded_ch = LOAD_RESULTS(load_in_ch)

  emit:
  final_outputs = loaded_ch
}
