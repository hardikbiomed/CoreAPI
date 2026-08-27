#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC_FILE="${REPO_ROOT}/APISpec/OpenAPI.yaml"
CONFIG_FILE="${REPO_ROOT}/codegen/configs/java.yaml"

# Validate spec file exists
if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: OpenAPI spec not found at ${SPEC_FILE}" >&2
  exit 1
fi

# Validate openapi-generator-cli is available
if ! command -v openapi-generator-cli &>/dev/null; then
  echo "ERROR: openapi-generator-cli not found on PATH" >&2
  exit 1
fi

# Run generator
openapi-generator-cli generate -c "$CONFIG_FILE" || {
  echo "ERROR: Java model generation failed" >&2
  exit 1
}

echo "Java models generated successfully."
