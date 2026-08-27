#!/usr/bin/env bash
# Property 1: Schema Coverage
# Validates: Requirements 2.1, 3.1, 4.1
#
# For every schema defined under components/schemas in OpenAPI.yaml,
# verify that a corresponding generated type file exists in each platform output.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC_FILE="${REPO_ROOT}/APISpec/OpenAPI.yaml"

JAVA_MODELS_DIR="${REPO_ROOT}/codegen/output/java/src/main/java/com/coreapi/models"
TYPESCRIPT_MODEL_DIR="${REPO_ROOT}/codegen/output/typescript/src"
DART_MODEL_DIR="${REPO_ROOT}/codegen/output/dart/lib"

# --- Helper functions ---

# Convert PascalCase schema name to snake_case for Dart file naming
to_snake_case() {
  local name="$1"
  # Insert underscore before each uppercase letter (except the first), then lowercase everything
  echo "$name" | sed -E 's/([A-Z])/_\1/g' | sed 's/^_//' | tr '[:upper:]' '[:lower:]'
}

# Convert PascalCase schema name to camelCase for TypeScript file naming
to_camel_case() {
  local name="$1"
  # Lowercase the first character
  echo "${name:0:1}" | tr '[:upper:]' '[:lower:]' | tr -d '\n'
  echo "${name:1}"
}

# --- Parse schemas from OpenAPI spec ---

if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: OpenAPI spec not found at ${SPEC_FILE}" >&2
  exit 1
fi

# Extract schema names: lines under 'components: schemas:' that are 4-space indented top-level keys
SCHEMAS=$(awk '
  /^  schemas:/ { found=1; next }
  found && /^  [^ ]/ { found=0 }
  found && /^    [A-Za-z]/ { gsub(/:.*/, ""); gsub(/^[[:space:]]+/, ""); print }
' "$SPEC_FILE")

if [[ -z "$SCHEMAS" ]]; then
  echo "ERROR: No schemas found in ${SPEC_FILE}" >&2
  exit 1
fi

TOTAL_SCHEMAS=$(echo "$SCHEMAS" | wc -l | tr -d ' ')
echo "Found ${TOTAL_SCHEMAS} schemas in OpenAPI spec."
echo ""

# --- Check each platform ---

MISSING_JAVA=()
MISSING_TS=()
MISSING_DART=()

while IFS= read -r schema; do
  # Skip empty lines
  [[ -z "$schema" ]] && continue

  # Java: PascalCase.java (schema name is already PascalCase)
  java_file="${JAVA_MODELS_DIR}/${schema}.java"
  if [[ ! -f "$java_file" ]]; then
    MISSING_JAVA+=("$schema")
  fi

  # TypeScript: The typescript-angular generator uses camelCase.ts for model files
  # It also may use a models/ subdirectory or a flat src/ directory
  ts_camel=$(to_camel_case "$schema")
  ts_found=0
  # Check common locations produced by typescript-angular generator
  for ts_candidate in \
    "${TYPESCRIPT_MODEL_DIR}/${ts_camel}.ts" \
    "${TYPESCRIPT_MODEL_DIR}/model/${ts_camel}.ts" \
    "${TYPESCRIPT_MODEL_DIR}/models/${ts_camel}.ts" \
    "${TYPESCRIPT_MODEL_DIR}/${schema}.ts" \
    "${TYPESCRIPT_MODEL_DIR}/model/${schema}.ts" \
    "${TYPESCRIPT_MODEL_DIR}/models/${schema}.ts"; do
    if [[ -f "$ts_candidate" ]]; then
      ts_found=1
      break
    fi
  done
  if [[ $ts_found -eq 0 ]]; then
    MISSING_TS+=("$schema")
  fi

  # Dart: snake_case.dart
  dart_snake=$(to_snake_case "$schema")
  dart_found=0
  for dart_candidate in \
    "${DART_MODEL_DIR}/${dart_snake}.dart" \
    "${DART_MODEL_DIR}/model/${dart_snake}.dart" \
    "${DART_MODEL_DIR}/src/model/${dart_snake}.dart"; do
    if [[ -f "$dart_candidate" ]]; then
      dart_found=1
      break
    fi
  done
  if [[ $dart_found -eq 0 ]]; then
    MISSING_DART+=("$schema")
  fi
done <<< "$SCHEMAS"

# --- Report results ---

EXIT_CODE=0

echo "=== Java Coverage ==="
if [[ ${#MISSING_JAVA[@]} -eq 0 ]]; then
  echo "  All ${TOTAL_SCHEMAS} schemas have corresponding Java files."
else
  echo "  MISSING ${#MISSING_JAVA[@]} of ${TOTAL_SCHEMAS} schemas:"
  for s in "${MISSING_JAVA[@]}"; do
    echo "    - $s (expected: ${JAVA_MODELS_DIR}/${s}.java)"
  done
  EXIT_CODE=1
fi
echo ""

echo "=== TypeScript Coverage ==="
if [[ ${#MISSING_TS[@]} -eq 0 ]]; then
  echo "  All ${TOTAL_SCHEMAS} schemas have corresponding TypeScript files."
else
  echo "  MISSING ${#MISSING_TS[@]} of ${TOTAL_SCHEMAS} schemas:"
  for s in "${MISSING_TS[@]}"; do
    echo "    - $s"
  done
  EXIT_CODE=1
fi
echo ""

echo "=== Dart Coverage ==="
if [[ ${#MISSING_DART[@]} -eq 0 ]]; then
  echo "  All ${TOTAL_SCHEMAS} schemas have corresponding Dart files."
else
  echo "  MISSING ${#MISSING_DART[@]} of ${TOTAL_SCHEMAS} schemas:"
  for s in "${MISSING_DART[@]}"; do
    echo "    - $s (expected: ${DART_MODEL_DIR}/$(to_snake_case "$s").dart)"
  done
  EXIT_CODE=1
fi
echo ""

# --- Summary ---
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "PASS: All schemas are covered in all platforms."
else
  echo "FAIL: Some schemas are missing from generated output."
fi

exit $EXIT_CODE
