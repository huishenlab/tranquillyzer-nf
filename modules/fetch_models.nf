process FETCH_MODELS {

  tag 'default_registry'
  label 'cpu'
  maxForks 1

  input:
  path 'seq_orders.yaml'
  val  expected_models   // list of model names (already filtered by skip list)

  output:
  val 'ok'

  script:
  // model_url_base is a Dropbox folder share. Force the zip-the-folder form (dl=1).
  def zip_url = params.model_url_base?.toString() ?: ''
  zip_url = zip_url.replaceAll(/([?&])dl=0(?=&|$)/, '$1dl=1')
  if (!(zip_url =~ /[?&]dl=1(?:&|$)/)) {
    zip_url = zip_url + (zip_url.contains('?') ? '&' : '?') + 'dl=1'
  }
  def expected_bash = expected_models.collect { "\"${it}\"" }.join(' ')
  """
  set -euo pipefail

  DEST="${params.models_dir}"
  mkdir -p "\${DEST}"

  EXPECTED=( ${expected_bash} )
  # Tranquillyzer's --models-dir convention is FLAT: the model's three files
  # live at the top of the dir, all sharing the model_name prefix.
  REQUIRED_SUFFIXES=( ".h5" "_lbl_bin.pkl" "_params.yaml" )

  # Idempotency: if every expected bundle is already on disk, skip download.
  ALL_PRESENT=1
  for m in "\${EXPECTED[@]}"; do
    for s in "\${REQUIRED_SUFFIXES[@]}"; do
      if [ ! -s "\${DEST}/\${m}\${s}" ]; then
        ALL_PRESENT=0
        break 2
      fi
    done
  done

  if [ "\${ALL_PRESENT}" = "1" ]; then
    echo "[fetch_models] cache hit — all expected bundles present under \${DEST}" >&2
    echo "[fetch_models] expected: \${EXPECTED[*]}" >&2
    exit 0
  fi

  echo "[fetch_models] downloading bundles archive from ${zip_url}" >&2
  curl -fL --retry 3 --retry-delay 2 -o bundles.zip "${zip_url}"

  # The Dropbox-generated zip contains a literal "/" root entry that breaks
  # `unzip` (exit 2: "stripped absolute path spec from /; mapname: conversion
  # of failed"). Python's zipfile is more forgiving — and we want to filter
  # the `archived/` subdir anyway, so extracting in Python is also cleaner.
  echo "[fetch_models] extracting (python zipfile, filtering archived/ and root entry)" >&2
  mkdir -p extracted
  python3 - <<'PYEOF'
import os, sys, zipfile
src, dest = 'bundles.zip', 'extracted'
os.makedirs(dest, exist_ok=True)
with zipfile.ZipFile(src) as z:
    for info in z.infolist():
        name = info.filename
        if not name or name in ('/', './'):
            continue
        if name.startswith('archived/') or '/archived/' in name:
            continue
        if name.endswith('/'):
            continue
        # Flatten to basename — the archive is shallow; we treat any nested
        # path as a flat top-level entry per the tranquillyzer convention.
        target = os.path.join(dest, os.path.basename(name))
        with z.open(info) as fin, open(target, 'wb') as fout:
            fout.write(fin.read())
PYEOF

  # Stage every model file we know about into DEST. Don't clobber existing
  # files (-n) so user-pre-populated bundles win.
  shopt -s nullglob
  for f in extracted/*.h5 extracted/*_lbl_bin.pkl extracted/*_params.yaml extracted/*_params.json; do
    base=\$(basename "\${f}")
    if [ ! -e "\${DEST}/\${base}" ]; then
      cp -a "\${f}" "\${DEST}/\${base}"
    fi
  done
  shopt -u nullglob

  # Soft validation: warn for any expected model whose files are missing, but
  # don't fail — seq_orders.yaml may list models whose v1.0.0-compatible
  # bundles aren't in the archive yet (e.g. older models that still ship
  # _params.json or use a `_w_CRF` suffix).
  MISSING_MODELS=()
  for m in "\${EXPECTED[@]}"; do
    HAVE_ALL=1
    for s in "\${REQUIRED_SUFFIXES[@]}"; do
      if [ ! -s "\${DEST}/\${m}\${s}" ]; then
        HAVE_ALL=0
        break
      fi
    done
    if [ "\${HAVE_ALL}" = "0" ]; then
      MISSING_MODELS+=( "\${m}" )
    fi
  done

  if [ "\${#MISSING_MODELS[@]}" -gt 0 ]; then
    echo "[fetch_models] WARNING: \${#MISSING_MODELS[@]} expected model(s) not fully present after extract:" >&2
    printf '  - %s\\n' "\${MISSING_MODELS[@]}" >&2
    echo "[fetch_models] These may have incompatible/old bundles in the archive (e.g. _params.json, _w_CRF suffix)." >&2
    echo "[fetch_models] tranquillyzer will error at runtime if --model-name points at one of these." >&2
  fi

  # Hard fail only if NOTHING landed — that means the archive was empty or the
  # archive structure changed completely.
  if ! ls "\${DEST}"/*.h5 >/dev/null 2>&1; then
    echo "ERROR: no model.h5 files landed under \${DEST} after extract — archive layout may have changed." >&2
    echo "Archive layout (top 30):" >&2
    ls extracted | head -30 >&2
    exit 1
  fi

  rm -rf extracted bundles.zip
  PRESENT_COUNT=\$(( \${#EXPECTED[@]} - \${#MISSING_MODELS[@]} ))
  echo "[fetch_models] OK — \${PRESENT_COUNT}/\${#EXPECTED[@]} expected bundle(s) ready under \${DEST}" >&2
  """
}
