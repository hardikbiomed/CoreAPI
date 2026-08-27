#!/usr/bin/env bash
# Property 7: Jackson Annotation Presence
# Validates: Requirements 2.2
#
# Verifies that every field in generated Java model classes is annotated
# with @JsonProperty. Enum classes are excluded from this check.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
JAVA_MODELS_DIR="${REPO_ROOT}/codegen/output/java/src/main/java/com/coreapi/models"

FAILURES=0
TOTAL_FILES=0
TOTAL_FIELDS=0
TOTAL_ANNOTATIONS=0

echo "=== Property 7: Jackson Annotation Presence ==="
echo "Java models directory: ${JAVA_MODELS_DIR}"
echo ""

# Check that the output directory exists and has Java files
if [[ ! -d "$JAVA_MODELS_DIR" ]]; then
  echo "ERROR: Java models directory not found at ${JAVA_MODELS_DIR}" >&2
  echo "Run 'make generate-java' to generate code before running this test." >&2
  exit 1
fi

JAVA_FILES=$(find "$JAVA_MODELS_DIR" -name "*.java" -type f 2>/dev/null)

if [[ -z "$JAVA_FILES" ]]; then
  echo "ERROR: No generated Java files found in ${JAVA_MODELS_DIR}" >&2
  echo "Run 'make generate-java' to generate code before running this test." >&2
  exit 1
fi

# --- Helper: Check if a Java file is an enum ---
is_enum_file() {
  local file="$1"
  grep -qE '^\s*public\s+enum\s+' "$file"
}

# --- Check a single Java class file for Jackson annotations ---
check_jackson_annotations() {
  local file="$1"
  local filename
  filename=$(basename "$file" .java)

  # Skip enum files - they don't have field annotations
  if is_enum_file "$file"; then
    echo "  [SKIP] ${filename} (enum class)"
    return 0
  fi

  TOTAL_FILES=$((TOTAL_FILES + 1))

  # Count declared fields (private or protected member variables)
  # Match lines like: private String fieldName; or private List<Foo> items = ...;
  local field_count
  field_count=$(grep -cE '^\s*(private|protected)\s+\S+.*\s+\w+\s*(=.*)?;' "$file" 2>/dev/null || echo "0")

  # Count @JsonProperty annotations
  local annotation_count
  annotation_count=$(grep -cE '^\s*@JsonProperty' "$file" 2>/dev/null || echo "0")

  TOTAL_FIELDS=$((TOTAL_FIELDS + field_count))
  TOTAL_ANNOTATIONS=$((TOTAL_ANNOTATIONS + annotation_count))

  if [[ "$field_count" -eq 0 ]]; then
    echo "  [SKIP] ${filename} (no fields found)"
    return 0
  fi

  # Find fields missing @JsonProperty by checking each field declaration
  local missing_fields=""
  local line_num=0
  local prev_has_annotation=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Check if this line has @JsonProperty
    if echo "$line" | grep -qE '^\s*@JsonProperty'; then
      prev_has_annotation=1
      continue
    fi

    # Check if this line is a field declaration
    if echo "$line" | grep -qE '^\s*(private|protected)\s+\S+.*\s+\w+\s*(=.*)?;'; then
      if [[ $prev_has_annotation -eq 0 ]]; then
        # Extract field name
        local field_name
        field_name=$(echo "$line" | sed -E 's/^\s*(private|protected)\s+\S+.*\s+(\w+)\s*(=.*)?;.*/\2/')
        if [[ -n "$missing_fields" ]]; then
          missing_fields="${missing_fields}, ${field_name}"
        else
          missing_fields="${field_name}"
        fi
      fi
      prev_has_annotation=0
    else
      # Reset annotation tracking if we hit a non-field, non-annotation line
      # But allow other annotations between @JsonProperty and the field
      if ! echo "$line" | grep -qE '^\s*@'; then
        prev_has_annotation=0
      fi
    fi
  done < "$file"

  if [[ -n "$missing_fields" ]]; then
    echo "  [FAIL] ${filename}: fields missing @JsonProperty: ${missing_fields}"
    echo "         (annotations: ${annotation_count}, fields: ${field_count})"
    FAILURES=$((FAILURES + 1))
    return 1
  fi

  if [[ "$annotation_count" -lt "$field_count" ]]; then
    echo "  [FAIL] ${filename}: annotation count (${annotation_count}) < field count (${field_count})"
    FAILURES=$((FAILURES + 1))
    return 1
  fi

  echo "  [PASS] ${filename} (${annotation_count} annotations, ${field_count} fields)"
  return 0
}

# --- Main: iterate over all Java files ---
echo "--- Checking @JsonProperty annotations ---"
echo ""

while IFS= read -r java_file; do
  [[ -z "$java_file" ]] && continue
  check_jackson_annotations "$java_file" || true
done <<< "$JAVA_FILES"

echo ""

# --- Summary ---
echo "=== Summary ==="
echo "Files checked: ${TOTAL_FILES}"
echo "Total fields: ${TOTAL_FIELDS}"
echo "Total @JsonProperty annotations: ${TOTAL_ANNOTATIONS}"
echo ""

if [[ $FAILURES -eq 0 ]]; then
  echo "PASS: All fields in generated Java classes have @JsonProperty annotations."
  exit 0
else
  echo "FAIL: ${FAILURES} file(s) have fields missing @JsonProperty annotations."
  exit 1
fi
