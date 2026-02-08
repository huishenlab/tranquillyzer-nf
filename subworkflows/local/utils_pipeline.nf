/*
 * ETL layout created under outdir (side-effect only):
 *   outdir/
 *     extract/
 *     transform/
 *     load/
 *     logs/
 *     pipeline_info/
 *
 * Emits a channel with tuples (OLD SHAPE):
 *   (sample_id, raw_dir, work_dir, metadata)
 */

process WRITE_NORMALIZED_SAMPLESHEET {

  tag "samplesheet.normalized"
  label 'cpu'

  input:
  path outdir_path
  path samplesheet_path
  val  rows_text

  output:
  path "samplesheet.normalized.tsv"

  script:
  """
  set -euo pipefail

  mkdir -p "${outdir_path}/extract"
  cp -f "${samplesheet_path}" "${outdir_path}/extract/samplesheet.original.tsv" || true

  cat > samplesheet.normalized.tsv << 'EOF'
  ${rows_text}
  EOF

  cp -f samplesheet.normalized.tsv "${outdir_path}/extract/samplesheet.normalized.tsv"
  """
}

workflow PIPELINE_INITIALISATION {

  take:
  outdir_in
  samplesheet_in
  reference_in
  container_trq_in
  container_subread_in

  main:

  if( !outdir_in )      error "Missing required --outdir"
  if( !samplesheet_in ) error "Missing required --samplesheet"
  if( !reference_in )   error "Missing required --reference"

  def outdir_path      = file(outdir_in)
  def samplesheet_path = file(samplesheet_in)
  def reference_path   = file(reference_in)

  if( !samplesheet_path.exists() )
    error "Samplesheet not found: ${samplesheet_path}"

  if( !reference_path.exists() )
    error "Reference FASTA not found: ${reference_path}"

  // Create ETL root structure (side effects only)
  outdir_path.mkdirs()
  def out_abs = outdir_path.toAbsolutePath().toString()

  def extract_root   = file("${out_abs}/extract")
  def transform_root = file("${out_abs}/transform")
  def load_root      = file("${out_abs}/load")
  def log_root       = file("${out_abs}/logs")
  def info_root      = file("${out_abs}/pipeline_info")

  [extract_root, transform_root, load_root, log_root, info_root].each { it.mkdirs() }

  log.info "=========================================="
  log.info " Tranquillyzer-NF initialisation (ETL roots created)"
  log.info "=========================================="
  log.info " samplesheet              : ${samplesheet_path}"
  log.info " outdir                   : ${outdir_path}"
  log.info " reference                : ${reference_path}"
  log.info " Tranquillyzer container  : ${container_trq_in}"
  log.info " featureCounts container  : ${container_subread_in}"
  log.info " ETL extract_root         : ${extract_root}"
  log.info " ETL transform_root       : ${transform_root}"
  log.info " ETL load_root            : ${load_root}"
  log.info " ETL log_root             : ${log_root}"
  log.info " ETL pipeline_info        : ${info_root}"
  log.info "=========================================="

  /*
   * Parse samplesheet TSV (header required).
   * Required columns: sample_id, raw_dir, metadata
   *
   * work_dir is the absolute outdir (same as old pipeline behavior).
   */
  parsed_ch = Channel
    .fromPath(samplesheet_path.toString(), checkIfExists: true)
    .splitCsv(header: true, sep: '\t')
    .map { row ->
      if( !row.sample_id ) error "Samplesheet missing required column 'sample_id' (or empty value)."
      if( !row.raw_dir )   error "Samplesheet missing required column 'raw_dir' (or empty value) for sample '${row.sample_id}'."
      if( !row.metadata )  error "Samplesheet missing required column 'metadata' (or empty value) for sample '${row.sample_id}'."

      def sample_id = row.sample_id.toString().trim()
      def raw_dir   = file(row.raw_dir.toString().trim())
      def metadata  = file(row.metadata.toString().trim())

      if( !raw_dir.exists() )  error "raw_dir not found for sample '${sample_id}': ${raw_dir}"
      if( !metadata.exists() ) error "metadata file not found for sample '${sample_id}': ${metadata}"

      def work_dir = out_abs  // <-- old behavior: everything under outdir

      tuple(sample_id, raw_dir, work_dir, metadata)
    }
    .ifEmpty {
      error "Samplesheet parsed to 0 rows. Ensure TSV header + required columns: sample_id, raw_dir, metadata."
    }

  /*
   * Normalized samplesheet written into Extract.
   * Match the emitted tuple shape: include work_dir (not run_dir).
   */
  norm_text_ch = parsed_ch
    .map { sid, raw_dir, work_dir, meta ->
      "${sid}\t${raw_dir.toAbsolutePath()}\t${meta.toAbsolutePath()}\t${work_dir}"
    }
    .collect()
    .map { rows ->
      def header = "sample_id\traw_dir\tmetadata\twork_dir"
      ( [header] + rows ).join("\n") + "\n"
    }

  WRITE_NORMALIZED_SAMPLESHEET(outdir_path, samplesheet_path, norm_text_ch)

  emit:
  samplesheet_ch = parsed_ch
}

workflow PIPELINE_COMPLETION {

  take:
  outdir_in
  final_outputs

  main:

  def outdir_path = file(outdir_in)

  if( final_outputs == null ) {
    log.warn "PIPELINE_COMPLETION: final_outputs is null (no outputs produced)."
    return
  }

  final_outputs
    .collect()
    .map { outs ->
      log.info "=========================================="
      log.info " Tranquillyzer-NF completed"
      log.info "=========================================="
      log.info " Results in: ${outdir_path}"
      log.info " Outputs emitted: ${outs.size()}"
      log.info "=========================================="
      return outs
    }

  emit:
  final_outputs
}