import groovy.json.JsonOutput

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Utility functions for Tranquillyzer Nextflow pipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def getGitRevision(projectDir) {
  try {
    def gitDir = new File("${projectDir}/.git")
    if (!gitDir.exists()) return null
    def proc = ['bash','-lc','git rev-parse --short HEAD'].execute(null, new File("${projectDir}"))
    proc.waitFor()
    return proc.exitValue() == 0 ? proc.in.text.trim() : null
  } catch (Exception e) {
    return null
  }
}

def getGitDirty(projectDir) {
  try {
    def gitDir = new File("${projectDir}/.git")
    if (!gitDir.exists()) return null
    def proc = ['bash','-lc','git status --porcelain'].execute(null, new File("${projectDir}"))
    proc.waitFor()
    if (proc.exitValue() != 0) return null
    return proc.in.text.trim() ? true : false
  } catch (Exception e) {
    return null
  }
}

def die(msg) {
  System.err.println("[tranquillyzer-nf] ERROR: ${msg}")
  System.exit(1)
}

def validateInputs(params) {
  if (!params.samplesheet) die("Missing required --samplesheet")
  if (!params.reference)  die("Missing required --reference")
  if (!params.outdir)     die("Missing required --outdir")

  def ss  = new File(params.samplesheet.toString())
  def ref = new File(params.reference.toString())

  if (!ss.exists())  die("Samplesheet not found: ${params.samplesheet}")
  if (!ref.exists()) die("Reference not found: ${params.reference}")

  if (params.gtf) {
    def gtf = new File(params.gtf.toString())
    if (!gtf.exists()) die("GTF not found: ${params.gtf}")
  }
}

/**
 * Convert Nextflow params (which can contain Paths, Files, Maps, Lists, etc.)
 * into a JSON-serializable structure.
 */
def toJsonSafe(obj) {
  if (obj == null) return null

  if (obj instanceof Map) {
    def out = [:]
    obj.each { k, v -> out[k.toString()] = toJsonSafe(v) }
    return out
  }

  if (obj instanceof List) {
    return obj.collect { toJsonSafe(it) }
  }

  if (obj.getClass().isArray()) {
    return obj.collect { toJsonSafe(it) }
  }

  if (obj instanceof File) return obj.toString()
  if (obj instanceof java.nio.file.Path) return obj.toString()
  if (obj instanceof GString) return obj.toString()

  if (obj instanceof Number || obj instanceof Boolean || obj instanceof String) {
    return obj
  }

  return obj.toString()
}

/**
 * Write an effective params file as JSON:
 * pipeline_info/params_effective.json
 *
 * {
 *   "meta": {...},
 *   "params": {...}
 * }
 */
def writeParamsEffectiveJson(outdir, params, meta=[:]) {
  def infoDir = new File("${outdir}/pipeline_info")
  infoDir.mkdirs()

  def f = new File(infoDir, 'params_effective.json')

  def payload = [
    meta  : toJsonSafe(meta ?: [:]),
    params: toJsonSafe(params as Map)
  ]

  f.text = JsonOutput.prettyPrint(JsonOutput.toJson(payload)) + "\n"
}