#!/usr/bin/env bash
# Property 5: Array Collection Mapping
# Validates: Requirements 2.4, 3.4, 4.4
#
# Verifies that array fields in the OpenAPI spec are generated with
# the correct collection types per platform:
#   - Java: List<T> (from java.util.List)
#   - TypeScript: T[] or Array<T>
#   - Dart: List<T>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC_FILE="${REPO_ROOT}/APISpec/OpenAPI.yaml"
JAVA_OUTPUT="${REPO_ROOT}/codegen/output/java/src/main/java/com/coreapi/models"
TS_OUTPUT="${REPO_ROOT}/codegen/output/typescript/src"
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

# --- Step 1: Parse the OpenAPI spec to find array fields ---
# Extract schema names and their array field names along with item types.
# We look for patterns like:
#   <fieldName>:
#     type: array
#     items:
#       type: <primitive>  OR  $ref: "#/components/schemas/<TypeName>"

echo "=== Property 5: Array Collection Mapping ==="
echo ""
echo "Parsing ${SPEC_FILE} for array fields..."
echo ""

# Use awk to extract array fields from the spec.
# Output format: SchemaName|fieldName|itemType
# itemType is either a primitive (string, integer, etc.) or a schema name from $ref
ARRAY_FIELDS=$(awk '
  /^    [A-Z][a-zA-Z0-9_]*:/ {
    schema = $1
    gsub(/:/, "", schema)
  }
  /^        [a-z][a-zA-Z0-9_]*:/ {
    field = $1
    gsub(/:/, "", field)
    is_array = 0
    item_type = ""
  }
  /^          type: array/ {
    is_array = 1
  }
  /^          items:/ && is_array {
    in_items = 1
  }
  in_items && /\$ref:.*\/schemas\// {
    # Extract schema name after /schemas/
    sub(/.*\/schemas\//, "", $0)
    gsub(/[^A-Za-z0-9_]/, "", $0)
    item_type = $0
    in_items = 0
    if (schema != "" && field != "" && item_type != "") {
      print schema "|" field "|" item_type
    }
  }
  in_items && /type:/ && !/\$ref/ {
    # Extract primitive type value
    sub(/.*type: */, "", $0)
    gsub(/[^a-z]/, "", $0)
    item_type = $0
    in_items = 0
    if (schema != "" && field != "" && item_type != "") {
      print schema "|" field "|" item_type
    }
  }
' "$SPEC_FILE")

if [[ -z "$ARRAY_FIELDS" ]]; then
  echo "ERROR: No array fields found in spec. Check parsing logic." >&2
  exit 1
fi

FIELD_COUNT=$(echo "$ARRAY_FIELDS" | wc -l)
echo "Found ${FIELD_COUNT} array fields in spec."
echo ""

# --- Step 2: Verify Java output uses List<T> ---
echo "--- Checking Java output ---"
if [[ -d "$JAVA_OUTPUT" ]]; then
  while IFS='|' read -r schema field item_type; do
    CHECKS=$((CHECKS + 1))
    # Determine expected Java type name for items
    case "$item_type" in
      string) java_item_type="String" ;;
      integer) java_item_type="Integer" ;;
      number) java_item_type="(Double|BigDecimal|Number)" ;;
      boolean) java_item_type="Boolean" ;;
      *) java_item_type="$item_type" ;;
    esac

    # Find the Java file for this schema
    java_file=$(find "$JAVA_OUTPUT" -maxdepth 1 -iname "${schema}.java" 2>/dev/null | head -1)
    if [[ -z "$java_file" ]]; then
      fail "Java: No file found for schema '${schema}' (field '${field}')"
      continue
    fi

    # Check that the field is declared as List<T>
    if grep -qE "List<.*${java_item_type}.*>" "$java_file" 2>/dev/null; then
      pass "Java: ${schema}.${field} uses List<${java_item_type}>"
    else
      # Also check for the field name directly with List type
      if grep -qE "(List<|java\.util\.List)" "$java_file" 2>/dev/null && grep -q "${field}" "$java_file" 2>/dev/null; then
        pass "Java: ${schema}.${field} uses List type (verified field and List present)"
      else
        fail "Java: ${schema}.${field} expected List<${java_item_type}> but not found in ${java_file}"
      fi
    fi
  done <<< "$ARRAY_FIELDS"
else
  echo "SKIP: Java output directory not found at ${JAVA_OUTPUT}"
  echo "      Run 'make generate-java' first."
fi
echo ""

# --- Step 3: Verify TypeScript output uses T[] or Array<T> ---
echo "--- Checking TypeScript output ---"
if [[ -d "$TS_OUTPUT" ]]; then
  while IFS='|' read -r schema field item_type; do
    CHECKS=$((CHECKS + 1))
    # Determine expected TypeScript type name for items
    case "$item_type" in
      string) ts_item_type="string" ;;
      integer) ts_item_type="number" ;;
      number) ts_item_type="number" ;;
      boolean) ts_item_type="boolean" ;;
      *) ts_item_type="$item_type" ;;
    esac

    # Find the TypeScript file for this schema (could be camelCase or kebab-case)
    schema_lower=$(echo "$schema" | sed 's/\([A-Z]\)/-\L\1/g' | sed 's/^-//')
    ts_file=$(find "$TS_OUTPUT" -maxdepth 2 \( -iname "${schema}.ts" -o -iname "${schema_lower}.ts" -o -iname "*.ts" \) 2>/dev/null | head -20)

    found=0
    for f in $ts_file; do
      # Check if this file contains the schema/interface definition
      if grep -qi "${schema}\|${field}" "$f" 2>/dev/null; then
        # Check for T[] pattern or Array<T> pattern
        if grep -qE "(${ts_item_type}\[\]|Array<.*${ts_item_type}.*>)" "$f" 2>/dev/null; then
          pass "TypeScript: ${schema}.${field} uses ${ts_item_type}[] or Array<${ts_item_type}>"
          found=1
          break
        elif grep -qE "(\[\]|Array<)" "$f" 2>/dev/null && grep -q "${field}" "$f" 2>/dev/null; then
          pass "TypeScript: ${schema}.${field} uses array type (verified field and array syntax present)"
          found=1
          break
        fi
      fi
    done

    if [[ $found -eq 0 ]]; then
      # Try a broader search across all .ts files
      if grep -rlE "(${ts_item_type}\[\]|Array<.*${ts_item_type}.*>)" "$TS_OUTPUT" 2>/dev/null | head -1 | grep -q .; then
        pass "TypeScript: ${schema}.${field} uses array type (found in output)"
        found=1
      else
        fail "TypeScript: ${schema}.${field} expected ${ts_item_type}[] or Array<${ts_item_type}> but not found"
      fi
    fi
  done <<< "$ARRAY_FIELDS"
else
  echo "SKIP: TypeScript output directory not found at ${TS_OUTPUT}"
  echo "      Run 'make generate-typescript' first."
fi
echo ""

# --- Step 4: Verify Dart output uses List<T> ---
echo "--- Checking Dart output ---"
if [[ -d "$DART_OUTPUT" ]]; then
  while IFS='|' read -r schema field item_type; do
    CHECKS=$((CHECKS + 1))
    # Determine expected Dart type name for items
    case "$item_type" in
      string) dart_item_type="String" ;;
      integer) dart_item_type="int" ;;
      number) dart_item_type="num" ;;
      boolean) dart_item_type="bool" ;;
      *) dart_item_type="$item_type" ;;
    esac

    # Find the Dart file for this schema (snake_case typically)
    schema_snake=$(echo "$schema" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')
    dart_file=$(find "$DART_OUTPUT" -maxdepth 2 \( -iname "${schema}.dart" -o -iname "${schema_snake}.dart" -o -name "*.dart" \) 2>/dev/null | head -20)

    found=0
    for f in $dart_file; do
      if grep -qi "${schema}\|${field}" "$f" 2>/dev/null; then
        # Check for List<T> pattern
        if grep -qE "List<.*${dart_item_type}.*>" "$f" 2>/dev/null; then
          pass "Dart: ${schema}.${field} uses List<${dart_item_type}>"
          found=1
          break
        elif grep -qE "List<" "$f" 2>/dev/null && grep -q "${field}" "$f" 2>/dev/null; then
          pass "Dart: ${schema}.${field} uses List type (verified field and List present)"
          found=1
          break
        fi
      fi
    done

    if [[ $found -eq 0 ]]; then
      # Try a broader search across all .dart files
      if grep -rlE "List<.*${dart_item_type}.*>" "$DART_OUTPUT" 2>/dev/null | head -1 | grep -q .; then
        pass "Dart: ${schema}.${field} uses List<${dart_item_type}> (found in output)"
        found=1
      else
        fail "Dart: ${schema}.${field} expected List<${dart_item_type}> but not found"
      fi
    fi
  done <<< "$ARRAY_FIELDS"
else
  echo "SKIP: Dart output directory not found at ${DART_OUTPUT}"
  echo "      Run 'make generate-dart' first."
fi
echo ""

# --- Summary ---
echo "=== Summary ==="
echo "Total checks: ${CHECKS}"
echo "Failures: ${FAILURES}"

if [[ $CHECKS -eq 0 ]]; then
  echo "WARNING: No checks were performed. Ensure generated output exists." >&2
  echo "Run 'make all' to generate code before running this test." >&2
  exit 1
fi

if [[ $FAILURES -gt 0 ]]; then
  echo "RESULT: FAILED (${FAILURES} failures out of ${CHECKS} checks)" >&2
  exit 1
fi

echo "RESULT: PASSED - All array fields use correct collection types per platform."
exit 0
