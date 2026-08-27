#!/usr/bin/env bash
# Property 8: Dart Serialization Annotation Presence
# Validates: Requirements 4.2
#
# For every generated Dart model class (excluding enums), verify that:
#   1. The class is annotated with @JsonSerializable() (or @JsonSerializable)
#   2. A fromJson factory constructor or method exists
#   3. A toJson method exists
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
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

echo "=== Property 8: Dart Serialization Annotation Presence ==="
echo ""

# --- Verify Dart output directory exists ---
if [[ ! -d "$DART_OUTPUT" ]]; then
  echo "ERROR: Dart output directory not found at ${DART_OUTPUT}" >&2
  echo "       Run 'make generate-dart' first." >&2
  exit 1
fi

# --- Find all Dart class files (exclude enum files and generated .g.dart files) ---
# Collect Dart files that contain a 'class' declaration (non-enum classes)
CLASS_FILES=()

while IFS= read -r dart_file; do
  # Skip generated part files (*.g.dart)
  if [[ "$dart_file" == *.g.dart ]]; then
    continue
  fi

  # Skip files that only contain enum definitions (no class keyword)
  if ! grep -qE '^\s*class\s+' "$dart_file" 2>/dev/null; then
    continue
  fi

  # Skip files that are purely enum files (contain enum but no non-enum class)
  # A file with a class keyword is considered a class file
  CLASS_FILES+=("$dart_file")
done < <(find "$DART_OUTPUT" -name "*.dart" -type f 2>/dev/null | sort)

if [[ ${#CLASS_FILES[@]} -eq 0 ]]; then
  echo "ERROR: No Dart class files found in ${DART_OUTPUT}" >&2
  echo "       Run 'make generate-dart' first." >&2
  exit 1
fi

echo "Found ${#CLASS_FILES[@]} Dart class file(s) to check."
echo ""

# --- Check each class file for serialization annotations ---
MISSING_ANNOTATION=()
MISSING_FROM_JSON=()
MISSING_TO_JSON=()

for dart_file in "${CLASS_FILES[@]}"; do
  filename=$(basename "$dart_file")
  CHECKS=$((CHECKS + 1))

  # Check 1: @JsonSerializable() or @JsonSerializable annotation
  if grep -qE '@JsonSerializable(\s*\(.*\))?' "$dart_file" 2>/dev/null; then
    pass "${filename}: has @JsonSerializable annotation"
  else
    fail "${filename}: missing @JsonSerializable annotation"
    MISSING_ANNOTATION+=("$filename")
  fi

  # Check 2: fromJson factory constructor or method
  CHECKS=$((CHECKS + 1))
  if grep -qE '(factory\s+\w+\.fromJson|fromJson|_\$\w+FromJson)' "$dart_file" 2>/dev/null; then
    pass "${filename}: has fromJson method/factory"
  else
    fail "${filename}: missing fromJson method/factory"
    MISSING_FROM_JSON+=("$filename")
  fi

  # Check 3: toJson method
  CHECKS=$((CHECKS + 1))
  if grep -qE '(toJson|_\$\w+ToJson)' "$dart_file" 2>/dev/null; then
    pass "${filename}: has toJson method"
  else
    fail "${filename}: missing toJson method"
    MISSING_TO_JSON+=("$filename")
  fi
done

echo ""

# --- Report summary ---
echo "=== Summary ==="
echo "Total class files checked: ${#CLASS_FILES[@]}"
echo "Total checks performed: ${CHECKS}"
echo "Failures: ${FAILURES}"
echo ""

if [[ ${#MISSING_ANNOTATION[@]} -gt 0 ]]; then
  echo "Classes missing @JsonSerializable:"
  for f in "${MISSING_ANNOTATION[@]}"; do
    echo "  - $f"
  done
  echo ""
fi

if [[ ${#MISSING_FROM_JSON[@]} -gt 0 ]]; then
  echo "Classes missing fromJson:"
  for f in "${MISSING_FROM_JSON[@]}"; do
    echo "  - $f"
  done
  echo ""
fi

if [[ ${#MISSING_TO_JSON[@]} -gt 0 ]]; then
  echo "Classes missing toJson:"
  for f in "${MISSING_TO_JSON[@]}"; do
    echo "  - $f"
  done
  echo ""
fi

# --- Final result ---
if [[ $FAILURES -gt 0 ]]; then
  echo "RESULT: FAILED (${FAILURES} failures out of ${CHECKS} checks)" >&2
  exit 1
fi

echo "RESULT: PASSED - All Dart class files have @JsonSerializable, fromJson, and toJson."
exit 0
