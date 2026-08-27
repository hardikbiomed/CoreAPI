#!/usr/bin/env bash
# Property 10: Models-Only Output Exclusion
# Validates: Requirements 5.1, 5.2, 5.3
#
# Verifies that no generated file across any platform output directory contains
# API client classes, HTTP method invocations, authentication logic, or
# endpoint route definitions.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

JAVA_MODELS_DIR="${REPO_ROOT}/codegen/output/java/src/main/java/com/coreapi/models"
TS_SRC_DIR="${REPO_ROOT}/codegen/output/typescript/src"
DART_LIB_DIR="${REPO_ROOT}/codegen/output/dart/lib"

VIOLATIONS=0

# --- Helper: scan files for forbidden patterns ---
# Arguments:
#   $1 - platform label (e.g., "JAVA", "TS", "DART")
#   $2 - directory to scan
#   $3 - file glob (e.g., "*.java", "*.ts", "*.dart")
scan_platform() {
  local platform="$1"
  local dir="$2"
  local glob="$3"

  if [[ ! -d "$dir" ]]; then
    echo "  [${platform}] SKIP: Output directory not found: ${dir}"
    return 0
  fi

  local files
  files=$(find "$dir" -name "$glob" -type f 2>/dev/null)

  if [[ -z "$files" ]]; then
    echo "  [${platform}] SKIP: No ${glob} files found in ${dir}"
    return 0
  fi

  local platform_violations=0

  # --- Pattern Group 1: API Client Classes ---
  # Look for class/interface declarations that indicate API client code
  # Use word boundaries and class declaration context to avoid false positives
  # on model property names like "clientId"
  local api_client_patterns=(
    "class ApiClient"
    "class HttpClient"
    "class ApiService"
    "class RestClient"
    "class ApiConfiguration"
    "class Configuration {"
    "interface ApiClient"
    "interface HttpClient"
    "class BaseAPI"
    "class DefaultApi"
  )

  for pattern in "${api_client_patterns[@]}"; do
    local matches
    matches=$(grep -rl "$pattern" $files 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      echo "  [${platform}] VIOLATION: API client pattern '${pattern}' found in:"
      echo "$matches" | while read -r f; do
        echo "    - ${f#${REPO_ROOT}/}"
      done
      platform_violations=$((platform_violations + 1))
    fi
  done

  # --- Pattern Group 2: HTTP Method Invocations ---
  # Look for HTTP method usage in code context (not in comments or string values
  # that might be model property names). Focus on method invocations and imports.
  local http_patterns=(
    "httpClient\."
    "http\.get\b"
    "http\.post\b"
    "http\.put\b"
    "http\.delete\b"
    "http\.patch\b"
    "\.request("
    "\.doGet("
    "\.doPost("
    "\.doPut("
    "\.doDelete("
    "fetch("
    "XMLHttpRequest"
    "HttpRequest\."
    "RequestMethod\."
    "import.*HttpClient"
    "import.*http"
  )

  for pattern in "${http_patterns[@]}"; do
    local matches
    matches=$(grep -rlE "$pattern" $files 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      echo "  [${platform}] VIOLATION: HTTP pattern '${pattern}' found in:"
      echo "$matches" | while read -r f; do
        echo "    - ${f#${REPO_ROOT}/}"
      done
      platform_violations=$((platform_violations + 1))
    fi
  done

  # --- Pattern Group 3: Authentication Logic ---
  # Look for auth-related class names, annotations, or logic patterns
  local auth_patterns=(
    "Bearer "
    "OAuth"
    "ApiKeyAuth"
    "Authorization"
    "BasicAuth"
    "BearerAuth"
    "ApiKey "
    "AuthSettings"
    "getAuthNames"
    "setAccessToken"
    "setApiKey"
  )

  for pattern in "${auth_patterns[@]}"; do
    local matches
    matches=$(grep -rl "$pattern" $files 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      echo "  [${platform}] VIOLATION: Auth pattern '${pattern}' found in:"
      echo "$matches" | while read -r f; do
        echo "    - ${f#${REPO_ROOT}/}"
      done
      platform_violations=$((platform_violations + 1))
    fi
  done

  # --- Pattern Group 4: Endpoint Route Definitions ---
  # Look for URL path patterns and route definitions
  local route_patterns=(
    '"/api/'
    "'/api/"
    "@Path("
    "@RequestMapping("
    "@GetMapping("
    "@PostMapping("
    "@PutMapping("
    "@DeleteMapping("
    "@Route("
    "basePath"
    "endpoint"
  )

  for pattern in "${route_patterns[@]}"; do
    local matches
    matches=$(grep -rl "$pattern" $files 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      echo "  [${platform}] VIOLATION: Route pattern '${pattern}' found in:"
      echo "$matches" | while read -r f; do
        echo "    - ${f#${REPO_ROOT}/}"
      done
      platform_violations=$((platform_violations + 1))
    fi
  done

  if [[ $platform_violations -eq 0 ]]; then
    local file_count
    file_count=$(echo "$files" | wc -l | tr -d ' ')
    echo "  [${platform}] PASS: ${file_count} files scanned, no API client/HTTP/auth/route patterns found."
  fi

  VIOLATIONS=$((VIOLATIONS + platform_violations))
}

# --- Main ---
echo "=== Property 10: Models-Only Output Exclusion ==="
echo ""
echo "Scanning generated output directories for forbidden patterns..."
echo "(API client classes, HTTP methods, auth logic, endpoint routes)"
echo ""

# Check that at least one output directory has generated files
JAVA_HAS_FILES=0
TS_HAS_FILES=0
DART_HAS_FILES=0

if [[ -d "$JAVA_MODELS_DIR" ]] && find "$JAVA_MODELS_DIR" -name "*.java" -type f | grep -q .; then
  JAVA_HAS_FILES=1
fi
if [[ -d "$TS_SRC_DIR" ]] && find "$TS_SRC_DIR" -name "*.ts" -type f | grep -q .; then
  TS_HAS_FILES=1
fi
if [[ -d "$DART_LIB_DIR" ]] && find "$DART_LIB_DIR" -name "*.dart" -type f | grep -q .; then
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

echo "--- Java ---"
scan_platform "JAVA" "$JAVA_MODELS_DIR" "*.java"
echo ""

echo "--- TypeScript ---"
scan_platform "TS" "$TS_SRC_DIR" "*.ts"
echo ""

echo "--- Dart ---"
scan_platform "DART" "$DART_LIB_DIR" "*.dart"
echo ""

# --- Summary ---
echo "=== Summary ==="
if [[ $VIOLATIONS -eq 0 ]]; then
  echo "PASS: No API client, HTTP, auth, or route patterns found. Output is models-only."
  exit 0
else
  echo "FAIL: ${VIOLATIONS} violation(s) detected. Generated output contains non-model code."
  exit 1
fi
