process READ_SEQ_ORDERS {

  tag 'default_registry'
  label 'cpu'
  maxForks 1

  output:
  path 'seq_orders.yaml'

  script:
  """
  set -euo pipefail

  REG_PATH="${params.seq_orders_in_container_path}"

  if [ ! -f "\${REG_PATH}" ]; then
    echo "ERROR: seq_orders registry not found at \${REG_PATH}" >&2
    echo "This should be the absolute path inside the tranquillyzer container." >&2
    echo "Override with --seq_orders_in_container_path <absolute-path>." >&2
    exit 1
  fi

  cp "\${REG_PATH}" seq_orders.yaml
  """
}
