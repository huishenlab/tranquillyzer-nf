nextflow.enable.dsl = 2

/*
 * ETL layout created under outdir:
 *   outdir/
 *     extract/
 *     transform/
 *     load/
 *     logs/
 *     pipeline_info/
 *
 * Emits a channel with tuples:
 *   (sample_id, raw_dir, run_dir, load_root, log_root, metadata)
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
  outdir
  samplesheet
  reference
  container_trq
  container_subread

  main:

  if( !outdir )      error "Missing required --outdir"
  if( !samplesheet ) error "Missing required --samplesheet"
  if( !reference )   error "Missing required --reference"

  def outdir_path       = file(outdir)
  def samplesheet_path  = file(samplesheet)
  def reference_path    = file(reference)

  if( !samplesheet_path.exists() )
    error "Samplesheet not found: ${samplesheet_path}"

  if( !reference_path.exists() )
    error "Reference FASTA not found: ${reference_path}"

  // Create ETL root structure
  outdir_path.mkdirs()
  def out_abs = outdir_path.toAbsolutePath().toString()

  def extract_root   = file("${out_abs}/extract")
  def transform_root = file("${out_abs}/transform")
  def load_root      = file("${out_abs}/load")
  def log_root       = file("${out_abs}/logs")

  [extract_root, transform_root, load_root, log_root].each { it.mkdirs() }

  log.info "=========================================="
  log.info " Tranquillyzer-NF initialisation (ETL)"
  log.info "=========================================="
  log.info " samplesheet              : ${samplesheet_path}"
  log.info " outdir                   : ${outdir_path}"
  log.info " reference                : ${reference_path}"
  log.info " Tranquillyzer container  : ${container_trq}"
  log.info " featureCounts container  : ${container_subread}"
  log.info " ETL extract_root         : ${extract_root}"
  log.info " ETL transform_root       : ${transform_root}"
  log.info " ETL load_root            : ${load_root}"
  log.info " ETL log_root             : ${log_root}"
  log.info "=========================================="

  /*
   * Parse samplesheet TSV (header required).
   * Required columns: sample_id, raw_dir, metadata
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

      // Persistent per-sample run directory (Transform)
      def run_dir = file("${transform_root}/${sample_id}/run")
      run_dir.mkdirs()

      tuple(sample_id, raw_dir, run_dir, load_root, log_root, metadata)
    }
    .ifEmpty {
      error "Samplesheet parsed to 0 rows. Ensure TSV header + required columns: sample_id, raw_dir, metadata."
    }

  /*
   * Write normalized samplesheet deterministically into Extract.
   * We create a textual table and write it via a process (reproducible & ordered).
   */
  norm_text_ch = parsed_ch
    .map { sid, raw_dir, run_dir, load_root2, log_root2, meta ->
      // one TSV row per sample
      "${sid}\t${raw_dir.toAbsolutePath()}\t${meta.toAbsolutePath()}\t${run_dir.toAbsolutePath()}"
    }
    .collect()
    .map { rows ->
      def header = "sample_id\traw_dir\tmetadata\trun_dir"
      ( [header] + rows ).join("\n") + "\n"
    }

  // Launch the writer process (side effect into outdir/extract)
  WRITE_NORMALIZED_SAMPLESHEET(outdir_path, samplesheet_path, norm_text_ch)

  emit:
  samplesheet_ch = parsed_ch
}

workflow PIPELINE_COMPLETION {

  take:
  outdir
  final_outputs

  main:

  def outdir_path = file(outdir)

  if( final_outputs == null ) {
    log.warn "PIPELINE_COMPLETION: final_outputs is null (no outputs produced)."
    return
  }

  final_outputs
    .collect()
    .map { outs ->
      log.info "=========================================="
      log.info " Tranquillyzer-NF completed (ETL)"
      log.info "=========================================="
      log.info " Results in: ${outdir_path}"
      log.info " Outputs emitted: ${outs.size()}"
      log.info "=========================================="
      return outs
    }

  emit:
  final_outputs
}