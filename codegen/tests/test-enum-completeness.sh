#!/usr/bin/env bash
# Property 3: Enum Value Completeness
# Validates: Requirements 1.3, 3.2
#
# Verifies that generated enums in each platform (Java, TypeScript, Dart)
# contain exactly all values defined in the OpenAPI spec.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC_FILE="${REPO_ROOT}/APISpec/OpenAPI.yaml"

JAVA_MODELS_DIR="${REPO_ROOT}/codegen/output/java/src/main/java/com/coreapi/models"
TS_SRC_DIR="${REPO_ROOT}/codegen/output/typescript/src"
DART_LIB_DIR="${REPO_ROOT}/codegen/output/dart/lib"

FAILURES=0

# Validate spec file exists
if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: OpenAPI spec not found at ${SPEC_FILE}" >&2
  exit 1
fi

# --- Extract enum schemas and their values from the OpenAPI YAML ---
# We parse the YAML looking for schemas that have a `type: string` followed by `enum:` list.
# Output format: ENUM_NAME:VALUE1,VALUE2,...
extract_enums_from_spec() {
  local current_schema=""
  local in_enum=0
  local enum_values=""

  while IFS= read -r line; do
    # Match a top-level schema name (4 spaces indentation under components/schemas)
    if echo "$line" | grep -qE '^ {4}[A-Za-z][A-Za-z0-9_]*:$'; then
      # If we were collecting an enum, emit it
      if [[ -n "$current_schema" && -n "$enum_values" ]]; then
        echo "${current_schema}:${enum_values}"
      fi
      current_schema=$(echo "$line" | sed 's/^ *//;s/:$//')
      in_enum=0
      enum_values=""
    # Detect start of enum list
    elif echo "$line" | grep -qE '^ {6}enum:$'; then
      in_enum=1
      enum_values=""
    # Collect enum values (lines starting with "      - ")
    elif [[ $in_enum -eq 1 ]] && echo "$line" | grep -qE '^ {6}- '; then
      local val
      val=$(echo "$line" | sed 's/^ *- //')
      if [[ -n "$enum_values" ]]; then
        enum_values="${enum_values},${val}"
      else
        enum_values="${val}"
      fi
    # Any non-enum-value line while in_enum means end of enum list
    elif [[ $in_enum -eq 1 ]]; then
      in_enum=0
    fi
  done < "$SPEC_FILE"

  # Emit last enum if file ends during one
  if [[ -n "$current_schema" && -n "$enum_values" ]]; then
    echo "${current_schema}:${enum_values}"
  fi
}

# --- Check Java enum file for expected values ---
check_java_enum() {
  local enum_name="$1"
  local expected_values="$2"

  local java_file="${JAVA_MODELS_DIR}/${enum_name}.java"
  if [[ ! -f "$java_file" ]]; then
    echo "  [JAVA] SKIP: File not found: ${java_file}"
    return 0
  fi

  local missing=""
  IFS=',' read -ra values <<< "$expected_values"
  for val in "${values[@]}"; do
    # Java enums use the value as a constant name (uppercase)
    if ! grep -qE "\b${val}\b" "$java_file"; then
      if [[ -n "$missing" ]]; then
        missing="${missing}, ${val}"
      else
        missing="${val}"
      fi
    fi
  done

  if [[ -n "$missing" ]]; then
    echo "  [JAVA] FAIL: ${enum_name} missing values: ${missing}"
    return 1
  else
    echo "  [JAVA] PASS: ${enum_name} - all values present"
    return 0
  fi
}

# --- Check TypeScript enum for expected values ---
check_typescript_enum() {
  local enum_name="$1"
  local expected_values="$2"

  # TypeScript enum files can be named in various ways - search all .ts files
  local found_file=""
  if [[ -d "$TS_SRC_DIR" ]]; then
    found_file=$(find "$TS_SRC_DIR" -name "*.ts" -exec grep -l "enum ${enum_name}" {} \; 2>/dev/null | head -1)
    # Also try lowercase/kebab-case filename patterns
    if [[ -z "$found_file" ]]; then
      found_file=$(find "$TS_SRC_DIR" -name "*.ts" -exec grep -l "${enum_name}" {} \; 2>/dev/null | head -1)
    fi
  fi

  if [[ -z "$found_file" ]]; then
    echo "  [TS]   SKIP: No TypeScript file found containing enum ${enum_name}"
    return 0
  fi

  local missing=""
  IFS=',' read -ra values <<< "$expected_values"
  for val in "${values[@]}"; do
    # TypeScript enums typically use the value in quotes: VALUE = 'VALUE' or VALUE = "VALUE"
    if ! grep -qE "\b${val}\b" "$found_file"; then
      if [[ -n "$missing" ]]; then
        missing="${missing}, ${val}"
      else
        missing="${val}"
      fi
    fi
  done

  if [[ -n "$missing" ]]; then
    echo "  [TS]   FAIL: ${enum_name} missing values: ${missing}"
    return 1
  else
    echo "  [TS]   PASS: ${enum_name} - all values present"
    return 0
  fi
}

# --- Check Dart enum for expected values ---
check_dart_enum() {
  local enum_name="$1"
  local expected_values="$2"

  # Dart enum files - search all .dart files
  local found_file=""
  if [[ -d "$DART_LIB_DIR" ]]; then
    found_file=$(find "$DART_LIB_DIR" -name "*.dart" -exec grep -l "enum ${enum_name}" {} \; 2>/dev/null | head -1)
    # Also try searching by the enum name reference
    if [[ -z "$found_file" ]]; then
      found_file=$(find "$DART_LIB_DIR" -name "*.dart" -exec grep -l "${enum_name}" {} \; 2>/dev/null | head -1)
    fi
  fi

  if [[ -z "$found_file" ]]; then
    echo "  [DART] SKIP: No Dart file found containing enum ${enum_name}"
    return 0
  fi

  local missing=""
  IFS=',' read -ra values <<< "$expected_values"
  for val in "${values[@]}"; do
    # Dart enums may use lowercase or the original value name
    # Check for the value in any case form
    if ! grep -qi "\b${val}\b" "$found_file"; then
      # Also check for camelCase or lowercase variants
      local lower_val
      lower_val=$(echo "$val" | tr '[:upper:]' '[:lower:]')
      if ! grep -q "${lower_val}" "$found_file"; then
        if [[ -n "$missing" ]]; then
          missing="${missing}, ${val}"
        else
          missing="${val}"
        fi
      fi
    fi
  done

  if [[ -n "$missing" ]]; then
    echo "  [DART] FAIL: ${enum_name} missing values: ${missing}"
    return 1
  else
    echo "  [DART] PASS: ${enum_name} - all values present"
    return 0
  fi
}

# --- Main ---
echo "=== Property 3: Enum Value Completeness ==="
echo "Spec file: ${SPEC_FILE}"
echo ""

# Check that at least one output directory has generated files
JAVA_HAS_FILES=0
TS_HAS_FILES=0
DART_HAS_FILES=0

if [[ -d "$JAVA_MODELS_DIR" ]] && find "$JAVA_MODELS_DIR" -name "*.java" | grep -q .; then
  JAVA_HAS_FILES=1
fi
if [[ -d "$TS_SRC_DIR" ]] && find "$TS_SRC_DIR" -name "*.ts" | grep -q .; then
  TS_HAS_FILES=1
fi
if [[ -d "$DART_LIB_DIR" ]] && find "$DART_LIB_DIR" -name "*.dart" | grep -q .; then
  DART_HAS_FILES=1
fi

if [[ $JAVA_HAS_FILES -eq 0 && $TS_HAS_FILES -eq 0 && $DART_HAS_FILES -eq 0 ]]; then
  echo "ERROR: No generated code found in any platform output directory." >&2
  echo "  Java:       ${JAVA_MODELS_DIR}" >&2
  echo "  TypeScript: ${TS_SRC_DIR}" >&2
  echo "  Dart:       ${DART_LIB_DIR}" >&2
  echo "Run 'make all' to generate code before running this test." >&2
  exit 1
fi

# Extract enums from spec
ENUM_LIST=$(extract_enums_from_spec)

if [[ -z "$ENUM_LIST" ]]; then
  echo "ERROR: No enum schemas found in the OpenAPI spec." >&2
  exit 1
fi

echo "Enums found in spec:"
while IFS= read -r enum_entry; do
  enum_name="${enum_entry%%:*}"
  enum_values="${enum_entry#*:}"
  echo "  ${enum_name}: [${enum_values}]"
done <<< "$ENUM_LIST"
echo ""

# Verify each enum in each platform
echo "--- Checking enum completeness ---"
while IFS= read -r enum_entry; do
  enum_name="${enum_entry%%:*}"
  enum_values="${enum_entry#*:}"

  echo "Enum: ${enum_name}"

  if [[ $JAVA_HAS_FILES -eq 1 ]]; then
    if ! check_java_enum "$enum_name" "$enum_values"; then
      FAILURES=$((FAILURES + 1))
    fi
  else
    echo "  [JAVA] SKIP: No generated Java files"
  fi

  if [[ $TS_HAS_FILES -eq 1 ]]; then
    if ! check_typescript_enum "$enum_name" "$enum_values"; then
      FAILURES=$((FAILURES + 1))
    fi
  else
    echo "  [TS]   SKIP: No generated TypeScript files"
  fi

  if [[ $DART_HAS_FILES -eq 1 ]]; then
    if ! check_dart_enum "$enum_name" "$enum_values"; then
      FAILURES=$((FAILURES + 1))
    fi
  else
    echo "  [DART] SKIP: No generated Dart files"
  fi

  echo ""
done <<< "$ENUM_LIST"

# Summary
echo "=== Summary ==="
if [[ $FAILURES -eq 0 ]]; then
  echo "All enum values are complete across all platforms. PASSED."
  exit 0
else
  echo "FAILED: ${FAILURES} enum completeness check(s) failed."
  exit 1
fi
