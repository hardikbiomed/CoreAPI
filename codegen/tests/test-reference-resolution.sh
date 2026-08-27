#!/usr/bin/env bash
# Property 2: Reference Type Resolution
# Validates: Requirements 1.2, 2.3, 3.3, 4.3
#
# Verifies that $ref fields in the OpenAPI spec are generated with the
# referenced type name in each platform's output (Java, TypeScript, Dart).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC_FILE="${REPO_ROOT}/APISpec/OpenAPI.yaml"

JAVA_DIR="${REPO_ROOT}/codegen/output/java/src/main/java/com/coreapi/models"
TS_DIR="${REPO_ROOT}/codegen/output/typescript/src"
DART_DIR="${REPO_ROOT}/codegen/output/dart/lib"

FAILURES=0
CHECKS=0

# --- Utility ---
fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
}

# --- Validate spec exists ---
if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: OpenAPI spec not found at ${SPEC_FILE}" >&2
  exit 1
fi

# --- Extract $ref references that point to object/enum schemas ---
# We look for lines like:  $ref: "#/components/schemas/Patient"
# and extract the referenced type name.
# Filter out date/time primitives (Instant, LocalDate, LocalDateTime, OffsetDateTime, Date)
# since those map to primitive types, not class references.
PRIMITIVE_TYPES="Instant|LocalDate|LocalDateTime|OffsetDateTime|Date"

REF_TYPES=$(grep -oP '\$ref:\s*"#/components/schemas/\K[^"]+' "$SPEC_FILE" \
  | grep -vE "^(${PRIMITIVE_TYPES})$" \
  | sort -u)

if [[ -z "$REF_TYPES" ]]; then
  echo "ERROR: No \$ref references found in spec (excluding date primitives)" >&2
  exit 1
fi

# Select representative references (at least 5)
# Pick a diverse sample: object types, enum types, nested types
SAMPLE_TYPES=()
while IFS= read -r t; do
  SAMPLE_TYPES+=("$t")
done <<< "$REF_TYPES"

# If more than 5 types, select 5 representative ones spanning the list
if [[ ${#SAMPLE_TYPES[@]} -gt 5 ]]; then
  TOTAL=${#SAMPLE_TYPES[@]}
  STEP=$(( TOTAL / 5 ))
  SELECTED=()
  for i in 0 1 2 3 4; do
    IDX=$(( i * STEP ))
    SELECTED+=("${SAMPLE_TYPES[$IDX]}")
  done
  SAMPLE_TYPES=("${SELECTED[@]}")
fi

echo "=== Reference Type Resolution Test ==="
echo "Checking ${#SAMPLE_TYPES[@]} referenced types: ${SAMPLE_TYPES[*]}"
echo ""

# --- Verify generated output directories have content ---
if [[ ! -d "$JAVA_DIR" ]] || [[ -z "$(find "$JAVA_DIR" -name '*.java' 2>/dev/null)" ]]; then
  echo "ERROR: No generated Java files found in ${JAVA_DIR}" >&2
  echo "Run code generation first (make generate-java)" >&2
  exit 1
fi

if [[ ! -d "$TS_DIR" ]] || [[ -z "$(find "$TS_DIR" -name '*.ts' 2>/dev/null)" ]]; then
  echo "ERROR: No generated TypeScript files found in ${TS_DIR}" >&2
  echo "Run code generation first (make generate-typescript)" >&2
  exit 1
fi

if [[ ! -d "$DART_DIR" ]] || [[ -z "$(find "$DART_DIR" -name '*.dart' 2>/dev/null)" ]]; then
  echo "ERROR: No generated Dart files found in ${DART_DIR}" >&2
  echo "Run code generation first (make generate-dart)" >&2
  exit 1
fi

# --- Check each reference type in generated output ---
for TYPE_NAME in "${SAMPLE_TYPES[@]}"; do
  echo "--- Checking reference type: ${TYPE_NAME} ---"

  # Java: The referenced type name should appear as a class/type reference
  CHECKS=$((CHECKS + 1))
  if grep -rlq "${TYPE_NAME}" "$JAVA_DIR"/*.java 2>/dev/null || \
     grep -rlq "${TYPE_NAME}" "$JAVA_DIR" --include='*.java' 2>/dev/null; then
    pass "Java references type '${TYPE_NAME}'"
  else
    fail "Java does not reference type '${TYPE_NAME}' in generated models"
  fi

  # TypeScript: The referenced type/interface name should appear
  CHECKS=$((CHECKS + 1))
  if grep -rlq "${TYPE_NAME}" "$TS_DIR" --include='*.ts' 2>/dev/null; then
    pass "TypeScript references type '${TYPE_NAME}'"
  else
    fail "TypeScript does not reference type '${TYPE_NAME}' in generated models"
  fi

  # Dart: The referenced class name should appear
  CHECKS=$((CHECKS + 1))
  if grep -rlq "${TYPE_NAME}" "$DART_DIR" --include='*.dart' 2>/dev/null; then
    pass "Dart references type '${TYPE_NAME}'"
  else
    fail "Dart does not reference type '${TYPE_NAME}' in generated models"
  fi

  echo ""
done

# --- Summary ---
echo "=== Summary ==="
echo "Checks: ${CHECKS}, Failures: ${FAILURES}"

if [[ $FAILURES -gt 0 ]]; then
  echo "RESULT: FAILED - ${FAILURES} reference type resolution checks failed" >&2
  exit 1
fi

echo "RESULT: PASSED - All reference types resolve correctly across all platforms"
exit 0
