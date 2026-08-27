#!/usr/bin/env bash
# Property 11: Generation Determinism
# Validates: Requirements 6.5
#
# Verifies that two consecutive invocations of the generation process with
# the same OpenAPI spec and generator version produce byte-for-byte identical
# output files.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC_FILE="${REPO_ROOT}/APISpec/OpenAPI.yaml"

# --- Prerequisites ---

if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: OpenAPI spec not found at ${SPEC_FILE}" >&2
  exit 1
fi

if ! command -v openapi-generator-cli &>/dev/null; then
  echo "SKIP: openapi-generator-cli not found on PATH. Cannot run determinism test." >&2
  echo "Install openapi-generator-cli to run this test."
  exit 0
fi

# --- Configuration ---

OUTPUT_DIRS=(
  "codegen/output/java"
  "codegen/output/typescript"
  "codegen/output/dart"
)

TEMP_DIR=$(mktemp -d)
CHECKSUMS_RUN1="${TEMP_DIR}/checksums_run1.txt"
CHECKSUMS_RUN2="${TEMP_DIR}/checksums_run2.txt"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# --- Helper: compute checksums for all generated files ---
# Produces a sorted list of "checksum  relative_path" lines
compute_checksums() {
  local output_file="$1"
  > "$output_file"

  for dir in "${OUTPUT_DIRS[@]}"; do
    local full_dir="${REPO_ROOT}/${dir}"
    if [[ -d "$full_dir" ]]; then
      # Find all files, compute sha256sum, make paths relative to repo root
      find "$full_dir" -type f | sort | while read -r file; do
        local rel_path="${file#${REPO_ROOT}/}"
        local checksum
        checksum=$(sha256sum "$file" | awk '{print $1}')
        echo "${checksum}  ${rel_path}" >> "$output_file"
      done
    fi
  done

  # Sort to ensure consistent ordering
  sort -k2 "$output_file" -o "$output_file"
}

# --- Run 1: Generate code ---
echo "=== Property 11: Generation Determinism ==="
echo ""
echo "--- Run 1: Generating code... ---"

# Clean output directories first
cd "$REPO_ROOT"
make clean 2>/dev/null || true

# Generate all platforms
make all || {
  echo "ERROR: First generation run failed" >&2
  exit 1
}

echo "Run 1 complete. Computing checksums..."
compute_checksums "$CHECKSUMS_RUN1"

RUN1_FILE_COUNT=$(wc -l < "$CHECKSUMS_RUN1" | tr -d ' ')
echo "  Files generated: ${RUN1_FILE_COUNT}"

if [[ $RUN1_FILE_COUNT -eq 0 ]]; then
  echo "ERROR: No files were generated in the first run." >&2
  exit 1
fi

# --- Run 2: Clean and regenerate ---
echo ""
echo "--- Run 2: Cleaning and regenerating code... ---"

make clean 2>/dev/null || true

make all || {
  echo "ERROR: Second generation run failed" >&2
  exit 1
}

echo "Run 2 complete. Computing checksums..."
compute_checksums "$CHECKSUMS_RUN2"

RUN2_FILE_COUNT=$(wc -l < "$CHECKSUMS_RUN2" | tr -d ' ')
echo "  Files generated: ${RUN2_FILE_COUNT}"

if [[ $RUN2_FILE_COUNT -eq 0 ]]; then
  echo "ERROR: No files were generated in the second run." >&2
  exit 1
fi

# --- Compare results ---
echo ""
echo "--- Comparing outputs... ---"

if diff "$CHECKSUMS_RUN1" "$CHECKSUMS_RUN2" > "${TEMP_DIR}/diff_output.txt" 2>&1; then
  echo ""
  echo "=== Summary ==="
  echo "PASS: Both generation runs produced byte-identical output (${RUN1_FILE_COUNT} files compared)."
  exit 0
else
  echo ""
  echo "=== Summary ==="
  echo "FAIL: Generation runs produced different output."
  echo ""
  echo "Differences:"
  # Show files that differ
  diff "$CHECKSUMS_RUN1" "$CHECKSUMS_RUN2" | head -50
  echo ""
  echo "Run 1 files: ${RUN1_FILE_COUNT}"
  echo "Run 2 files: ${RUN2_FILE_COUNT}"
  exit 1
fi
