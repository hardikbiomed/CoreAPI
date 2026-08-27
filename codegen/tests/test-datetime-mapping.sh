#!/usr/bin/env bash
# Property 4: Date/Time Type Mapping
# Validates: Requirements 1.4, 3.6
#
# For any field with format `date` or `date-time` in the OpenAPI spec,
# and for any target platform, the generated type SHALL match the platform's
# designated date/time mapping:
#   - Java: date → java.time.LocalDate / LocalDate, date-time → java.time.OffsetDateTime / OffsetDateTime
#   - TypeScript: both date and date-time → string
#   - Dart: both date and date-time → DateTime

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC_FILE="${REPO_ROOT}/APISpec/OpenAPI.yaml"

JAVA_OUTPUT="${REPO_ROOT}/codegen/output/java/src/main/java/com/coreapi/models"
TS_OUTPUT="${REPO_ROOT}/codegen/output/typescript/src"
DART_OUTPUT="${REPO_ROOT}/codegen/output/dart/lib"

FAILURES=0

fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
}

# --- Step 1: Parse the OpenAPI spec for date/date-time schemas ---
# Identify schemas that are format: date or format: date-time
# These are top-level schemas like Date, LocalDate (format: date)
# and Instant, LocalDateTime, OffsetDateTime (format: date-time)

echo "=== Property 4: Date/Time Type Mapping ==="
echo ""
echo "Checking that date/date-time fields map to correct platform types..."
echo ""

# Verify spec file exists
if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: OpenAPI spec not found at ${SPEC_FILE}" >&2
  exit 1
fi

# --- Step 2: Check Java date/time mappings ---
echo "--- Java Mappings ---"

if [[ -d "$JAVA_OUTPUT" ]] && ls "$JAVA_OUTPUT"/*.java &>/dev/null; then
  # In Java: date → LocalDate, date-time → OffsetDateTime
  # Fields referencing LocalDate schema should use java.time.LocalDate or LocalDate
  # Fields referencing Instant/LocalDateTime/OffsetDateTime should use java.time.OffsetDateTime or OffsetDateTime

  # Check that date-time types resolve to OffsetDateTime in Java
  # Look for fields that should be OffsetDateTime (Instant, LocalDateTime, OffsetDateTime schemas)
  JAVA_HAS_OFFSET_DT=false
  if grep -rl "OffsetDateTime" "$JAVA_OUTPUT" &>/dev/null; then
    JAVA_HAS_OFFSET_DT=true
  fi

  # Check that date types resolve to LocalDate in Java
  JAVA_HAS_LOCAL_DATE=false
  if grep -rl "LocalDate" "$JAVA_OUTPUT" | grep -v "LocalDateTime" &>/dev/null; then
    JAVA_HAS_LOCAL_DATE=true
  fi

  # Verify AdmissionDTO has LocalDate for admissionDate (references LocalDate schema which is format: date)
  ADMISSION_FILE=$(find "$JAVA_OUTPUT" -name "AdmissionDTO.java" 2>/dev/null | head -1)
  if [[ -n "$ADMISSION_FILE" && -f "$ADMISSION_FILE" ]]; then
    if grep -q "LocalDate" "$ADMISSION_FILE"; then
      pass "Java AdmissionDTO uses LocalDate for date fields"
    else
      fail "Java AdmissionDTO missing LocalDate for date fields (admissionDate/dischargeDate)"
    fi

    # admissionTime/dischargeTime/createdAt/updatedAt reference LocalDateTime which is format: date-time
    if grep -q "OffsetDateTime" "$ADMISSION_FILE"; then
      pass "Java AdmissionDTO uses OffsetDateTime for date-time fields"
    else
      fail "Java AdmissionDTO missing OffsetDateTime for date-time fields (admissionTime/dischargeTime/createdAt/updatedAt)"
    fi
  else
    # Check any Java file for presence of date-time type usage
    if [[ "$JAVA_HAS_OFFSET_DT" == true ]]; then
      pass "Java output contains OffsetDateTime for date-time mapped fields"
    else
      fail "Java output does not contain OffsetDateTime for date-time fields"
    fi

    if [[ "$JAVA_HAS_LOCAL_DATE" == true ]]; then
      pass "Java output contains LocalDate for date mapped fields"
    else
      fail "Java output does not contain LocalDate for date fields"
    fi
  fi

  # Verify ApplicationLicense uses LocalDate for validityStart/validityEnd (references Date schema, format: date)
  LICENSE_FILE=$(find "$JAVA_OUTPUT" -name "ApplicationLicense.java" 2>/dev/null | head -1)
  if [[ -n "$LICENSE_FILE" && -f "$LICENSE_FILE" ]]; then
    if grep -q "LocalDate" "$LICENSE_FILE"; then
      pass "Java ApplicationLicense uses LocalDate for date fields (validityStart/validityEnd)"
    else
      fail "Java ApplicationLicense missing LocalDate for date fields (validityStart/validityEnd)"
    fi
  fi

  # Negative check: date/date-time fields should NOT map to plain String in Java
  # Check that fields we know are dates aren't just String
  if [[ -n "${ADMISSION_FILE:-}" && -f "${ADMISSION_FILE:-}" ]]; then
    # admissionDate should not be String type
    if grep -E "(private|protected)\s+String\s+admissionDate" "$ADMISSION_FILE" &>/dev/null; then
      fail "Java AdmissionDTO incorrectly maps admissionDate as String instead of LocalDate"
    else
      pass "Java AdmissionDTO does not incorrectly use String for date fields"
    fi
  fi
else
  echo "  SKIP: Java output not generated yet (no .java files in $JAVA_OUTPUT)"
fi

echo ""

# --- Step 3: Check TypeScript date/time mappings ---
echo "--- TypeScript Mappings ---"

if [[ -d "$TS_OUTPUT" ]] && find "$TS_OUTPUT" -name "*.ts" ! -name ".gitkeep" | grep -q .; then
  # In TypeScript: both date and date-time → string
  # Fields referencing date/date-time schemas should be typed as string (or optional string)

  # Find TypeScript file for AdmissionDTO
  TS_ADMISSION=$(find "$TS_OUTPUT" -iname "*admission*" -name "*.ts" 2>/dev/null | head -1)
  if [[ -n "$TS_ADMISSION" && -f "$TS_ADMISSION" ]]; then
    # admissionDate should be string type (not Date, not number)
    if grep -q "admissionDate" "$TS_ADMISSION"; then
      # Check it's typed as string (could be `admissionDate?: string` or `admissionDate: string`)
      if grep -E "admissionDate\??\s*:\s*string" "$TS_ADMISSION" &>/dev/null; then
        pass "TypeScript AdmissionDTO maps admissionDate as string"
      else
        fail "TypeScript AdmissionDTO does not map admissionDate as string"
      fi
    fi

    # admissionTime (date-time) should also be string
    if grep -q "admissionTime" "$TS_ADMISSION"; then
      if grep -E "admissionTime\??\s*:\s*string" "$TS_ADMISSION" &>/dev/null; then
        pass "TypeScript AdmissionDTO maps admissionTime (date-time) as string"
      else
        fail "TypeScript AdmissionDTO does not map admissionTime as string"
      fi
    fi
  fi

  # Check ApplicationLicense TypeScript mapping
  TS_LICENSE=$(find "$TS_OUTPUT" -iname "*license*" -name "*.ts" 2>/dev/null | head -1)
  if [[ -n "$TS_LICENSE" && -f "$TS_LICENSE" ]]; then
    if grep -q "validityStart" "$TS_LICENSE"; then
      if grep -E "validityStart\??\s*:\s*string" "$TS_LICENSE" &>/dev/null; then
        pass "TypeScript ApplicationLicense maps validityStart (date) as string"
      else
        fail "TypeScript ApplicationLicense does not map validityStart as string"
      fi
    fi
  fi

  # Negative check: no Date or DateTime type should appear for date fields in TypeScript
  if find "$TS_OUTPUT" -name "*.ts" -exec grep -l ":\s*Date" {} \; 2>/dev/null | grep -q .; then
    fail "TypeScript output incorrectly uses Date type for date fields (should be string)"
  else
    pass "TypeScript output does not use Date type (correctly uses string)"
  fi
else
  echo "  SKIP: TypeScript output not generated yet (no .ts files in $TS_OUTPUT)"
fi

echo ""

# --- Step 4: Check Dart date/time mappings ---
echo "--- Dart Mappings ---"

if [[ -d "$DART_OUTPUT" ]] && find "$DART_OUTPUT" -name "*.dart" ! -name ".gitkeep" | grep -q .; then
  # In Dart: both date and date-time → DateTime

  # Find Dart file for AdmissionDTO
  DART_ADMISSION=$(find "$DART_OUTPUT" -iname "*admission*" -name "*.dart" 2>/dev/null | head -1)
  if [[ -n "$DART_ADMISSION" && -f "$DART_ADMISSION" ]]; then
    # admissionDate should be DateTime type
    if grep -q "admissionDate" "$DART_ADMISSION"; then
      if grep -E "DateTime\??\s+admissionDate" "$DART_ADMISSION" &>/dev/null; then
        pass "Dart AdmissionDTO maps admissionDate as DateTime"
      else
        fail "Dart AdmissionDTO does not map admissionDate as DateTime"
      fi
    fi

    # admissionTime (date-time) should also be DateTime
    if grep -q "admissionTime" "$DART_ADMISSION"; then
      if grep -E "DateTime\??\s+admissionTime" "$DART_ADMISSION" &>/dev/null; then
        pass "Dart AdmissionDTO maps admissionTime (date-time) as DateTime"
      else
        fail "Dart AdmissionDTO does not map admissionTime as DateTime"
      fi
    fi
  fi

  # Check ApplicationLicense Dart mapping
  DART_LICENSE=$(find "$DART_OUTPUT" -iname "*license*" -name "*.dart" 2>/dev/null | head -1)
  if [[ -n "$DART_LICENSE" && -f "$DART_LICENSE" ]]; then
    if grep -q "validityStart" "$DART_LICENSE"; then
      if grep -E "DateTime\??\s+validityStart" "$DART_LICENSE" &>/dev/null; then
        pass "Dart ApplicationLicense maps validityStart (date) as DateTime"
      else
        fail "Dart ApplicationLicense does not map validityStart as DateTime"
      fi
    fi
  fi

  # Verify that date/time fields are not mapped to String in Dart
  if [[ -n "${DART_ADMISSION:-}" && -f "${DART_ADMISSION:-}" ]]; then
    if grep -E "String\??\s+admissionDate" "$DART_ADMISSION" &>/dev/null; then
      fail "Dart AdmissionDTO incorrectly maps admissionDate as String instead of DateTime"
    else
      pass "Dart AdmissionDTO does not incorrectly use String for date fields"
    fi
  fi
else
  echo "  SKIP: Dart output not generated yet (no .dart files in $DART_OUTPUT)"
fi

echo ""

# --- Summary ---
echo "=== Summary ==="
if [[ $FAILURES -eq 0 ]]; then
  echo "All date/time type mapping checks passed."
  exit 0
else
  echo "$FAILURES check(s) failed." >&2
  exit 1
fi
