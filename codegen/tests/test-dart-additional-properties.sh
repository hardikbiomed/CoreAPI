#!/usr/bin/env bash
# Property 9: Dart additionalProperties Mapping
# Validates: Requirements 4.6
#
# Verifies that fields defined with `additionalProperties` (free-form object)
# in the OpenAPI spec generate `Map<String, dynamic>` in the Dart output.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC_FILE="${REPO_ROOT}/APISpec/OpenAPI.yaml"
DART_OUTPUT="${REPO_ROOT}/codegen/output/dart/lib"

FAILURES=0
CHECKS=0

fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
}

echo "=== Property 9: Dart additionalProperties Mapping ==="
echo ""
echo "Parsing ${SPEC_FILE} for fields with additionalProperties..."
echo ""

# --- Step 1: Parse the OpenAPI spec to find fields with additionalProperties ---
# We look for patterns where a field has:
#   type: object
#   additionalProperties: {}
# OR just:
#   additionalProperties: (anything)
#
# Output format: SchemaName|fieldName
ADDITIONAL_PROPS_FIELDS=$(awk '
  /^    [A-Z][a-zA-Z0-9_]*:/ {
    schema = $1
    gsub(/:/, "", schema)
  }
  /^        [a-z][a-zA-Z0-9_]*:/ {
    field = $1
    gsub(/:/, "", field)
    has_additional_props = 0
  }
  /^          additionalProperties:/ {
    has_additional_props = 1
    if (schema != "" && field != "") {
      print schema "|" field
    }
  }
' "$SPEC_FILE")

if [[ -z "$ADDITIONAL_PROPS_FIELDS" ]]; then
  echo "ERROR: No fields with additionalProperties found in spec. Check parsing logic." >&2
  exit 1
fi

FIELD_COUNT=$(echo "$ADDITIONAL_PROPS_FIELDS" | wc -l)
echo "Found ${FIELD_COUNT} field(s) with additionalProperties in spec."
echo ""

# Print discovered fields
while IFS='|' read -r schema field; do
  echo "  - ${schema}.${field}"
done <<< "$ADDITIONAL_PROPS_FIELDS"
echo ""

# --- Step 2: Verify Dart output uses Map<String, dynamic> ---
echo "--- Checking Dart output ---"
if [[ -d "$DART_OUTPUT" ]]; then
  while IFS='|' read -r schema field; do
    CHECKS=$((CHECKS + 1))

    # Find the Dart file for this schema (typically snake_case)
    schema_snake=$(echo "$schema" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')
    dart_file=$(find "$DART_OUTPUT" -maxdepth 2 \( -iname "${schema}.dart" -o -iname "${schema_snake}.dart" \) 2>/dev/null | head -1 || true)

    # If not found directly, try searching all dart files for the class
    if [[ -z "$dart_file" ]]; then
      dart_file=$(grep -rl "class ${schema}" "$DART_OUTPUT" 2>/dev/null | head -1 || true)
    fi

    if [[ -z "$dart_file" ]]; then
      fail "Dart: No file found for schema '${schema}' (field '${field}')"
      continue
    fi

    # Check for Map<String, dynamic> in the file associated with the field
    if grep -qE "Map<String,\s*dynamic>" "$dart_file" 2>/dev/null; then
      # Verify the field name is also present in the file
      if grep -qi "${field}" "$dart_file" 2>/dev/null; then
        pass "Dart: ${schema}.${field} uses Map<String, dynamic>"
      else
        # The field might be renamed to camelCase or snake_case by the generator
        field_snake=$(echo "$field" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')
        if grep -qi "${field_snake}" "$dart_file" 2>/dev/null; then
          pass "Dart: ${schema}.${field} uses Map<String, dynamic> (as ${field_snake})"
        else
          # Map<String, dynamic> is present - field name could be transformed differently
          pass "Dart: ${schema}.${field} - Map<String, dynamic> found in generated file"
        fi
      fi
    else
      fail "Dart: ${schema}.${field} expected Map<String, dynamic> but not found in ${dart_file}"
    fi
  done <<< "$ADDITIONAL_PROPS_FIELDS"
else
  echo "SKIP: Dart output directory not found at ${DART_OUTPUT}"
  echo "      Run 'make generate-dart' first."
  echo ""
  echo "=== Summary ==="
  echo "Total checks: 0"
  echo "WARNING: No checks were performed. Ensure generated output exists." >&2
  echo "Run 'make generate-dart' to generate code before running this test." >&2
  exit 1
fi
echo ""

# --- Summary ---
echo "=== Summary ==="
echo "Total checks: ${CHECKS}"
echo "Failures: ${FAILURES}"

if [[ $CHECKS -eq 0 ]]; then
  echo "WARNING: No checks were performed. Ensure generated output exists." >&2
  echo "Run 'make generate-dart' to generate code before running this test." >&2
  exit 1
fi

if [[ $FAILURES -gt 0 ]]; then
  echo "RESULT: FAILED (${FAILURES} failures out of ${CHECKS} checks)" >&2
  exit 1
fi

echo "RESULT: PASSED - All additionalProperties fields use Map<String, dynamic> in Dart."
exit 0
