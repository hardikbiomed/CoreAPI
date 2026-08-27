#!/usr/bin/env bash
# Property 6: Java Numeric Format Mapping
# Validates: Requirements 2.5, 2.6
#
# For any numeric field in the OpenAPI spec with an explicit format,
# the generated Java code SHALL use the format-specific type:
#   - format: int32 → Integer
#   - format: int64 → Long
#   - format: double → Double

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC_FILE="${REPO_ROOT}/APISpec/OpenAPI.yaml"

JAVA_OUTPUT="${REPO_ROOT}/codegen/output/java/src/main/java/com/coreapi/models"

FAILURES=0

fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
}

echo "=== Property 6: Java Numeric Format Mapping ==="
echo ""
echo "Checking that numeric fields with explicit formats map to correct Java types..."
echo ""

# Verify spec file exists
if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: OpenAPI spec not found at ${SPEC_FILE}" >&2
  exit 1
fi

# Check Java output exists
if [[ ! -d "$JAVA_OUTPUT" ]] || ! ls "$JAVA_OUTPUT"/*.java &>/dev/null; then
  echo "SKIP: Java output not generated yet (no .java files in $JAVA_OUTPUT)"
  exit 0
fi

echo "--- Checking int32 → Integer mappings ---"
echo ""

# ApplicationLicense: usersLimit, reportFormatLimit, currentUsers, currentReportFormat, currentReports are int32
LICENSE_FILE=$(find "$JAVA_OUTPUT" -name "ApplicationLicense.java" 2>/dev/null | head -1)
if [[ -n "$LICENSE_FILE" && -f "$LICENSE_FILE" ]]; then
  for field in usersLimit reportFormatLimit currentUsers currentReportFormat currentReports; do
    if grep -qE "(private|protected)\s+Integer\s+$field" "$LICENSE_FILE"; then
      pass "ApplicationLicense.$field uses Integer (int32)"
    elif grep -qE "$field" "$LICENSE_FILE"; then
      # Field exists but might not be Integer
      if grep -qE "(private|protected)\s+int\s+$field" "$LICENSE_FILE"; then
        # primitive int is also acceptable for int32
        pass "ApplicationLicense.$field uses int (int32 primitive)"
      else
        fail "ApplicationLicense.$field does not use Integer for int32 format"
      fi
    fi
  done
else
  fail "ApplicationLicense.java not found in Java output"
fi

# BillingItemDTO: billingItemID, quantity are int32
BILLING_ITEM_DTO_FILE=$(find "$JAVA_OUTPUT" -name "BillingItemDTO.java" 2>/dev/null | head -1)
if [[ -n "$BILLING_ITEM_DTO_FILE" && -f "$BILLING_ITEM_DTO_FILE" ]]; then
  for field in billingItemID quantity; do
    if grep -qE "(private|protected)\s+Integer\s+$field" "$BILLING_ITEM_DTO_FILE"; then
      pass "BillingItemDTO.$field uses Integer (int32)"
    elif grep -qE "(private|protected)\s+int\s+$field" "$BILLING_ITEM_DTO_FILE"; then
      pass "BillingItemDTO.$field uses int (int32 primitive)"
    elif grep -qE "$field" "$BILLING_ITEM_DTO_FILE"; then
      fail "BillingItemDTO.$field does not use Integer for int32 format"
    fi
  done
else
  fail "BillingItemDTO.java not found in Java output"
fi

# SystemConfig: id, passwordExpiryinDays are int32
SYSTEM_CONFIG_FILE=$(find "$JAVA_OUTPUT" -name "SystemConfig.java" 2>/dev/null | head -1)
if [[ -n "$SYSTEM_CONFIG_FILE" && -f "$SYSTEM_CONFIG_FILE" ]]; then
  for field in id passwordExpiryinDays; do
    if grep -qE "(private|protected)\s+Integer\s+$field" "$SYSTEM_CONFIG_FILE"; then
      pass "SystemConfig.$field uses Integer (int32)"
    elif grep -qE "(private|protected)\s+int\s+$field" "$SYSTEM_CONFIG_FILE"; then
      pass "SystemConfig.$field uses int (int32 primitive)"
    elif grep -qE "$field" "$SYSTEM_CONFIG_FILE"; then
      fail "SystemConfig.$field does not use Integer for int32 format"
    fi
  done
else
  fail "SystemConfig.java not found in Java output"
fi

echo ""
echo "--- Checking double → Double mappings ---"
echo ""

# BillingItemDTO: itemCost, taxInPercentage, subtotal, taxAmount, total are double
if [[ -n "$BILLING_ITEM_DTO_FILE" && -f "$BILLING_ITEM_DTO_FILE" ]]; then
  for field in itemCost taxInPercentage subtotal taxAmount total; do
    if grep -qE "(private|protected)\s+Double\s+$field" "$BILLING_ITEM_DTO_FILE"; then
      pass "BillingItemDTO.$field uses Double (double format)"
    elif grep -qE "(private|protected)\s+double\s+$field" "$BILLING_ITEM_DTO_FILE"; then
      pass "BillingItemDTO.$field uses double primitive (double format)"
    elif grep -qE "$field" "$BILLING_ITEM_DTO_FILE"; then
      fail "BillingItemDTO.$field does not use Double for double format"
    fi
  done
else
  fail "BillingItemDTO.java not found in Java output (double check)"
fi

# PatientBill: totalAmount, paidAmount, balanceAmount are double
PATIENT_BILL_FILE=$(find "$JAVA_OUTPUT" -name "PatientBill.java" 2>/dev/null | head -1)
if [[ -n "$PATIENT_BILL_FILE" && -f "$PATIENT_BILL_FILE" ]]; then
  for field in totalAmount paidAmount balanceAmount; do
    if grep -qE "(private|protected)\s+Double\s+$field" "$PATIENT_BILL_FILE"; then
      pass "PatientBill.$field uses Double (double format)"
    elif grep -qE "(private|protected)\s+double\s+$field" "$PATIENT_BILL_FILE"; then
      pass "PatientBill.$field uses double primitive (double format)"
    elif grep -qE "$field" "$PATIENT_BILL_FILE"; then
      fail "PatientBill.$field does not use Double for double format"
    fi
  done
else
  fail "PatientBill.java not found in Java output"
fi

# PatientBillingPaymentHistory: amountPaid is double
PAYMENT_HISTORY_FILE=$(find "$JAVA_OUTPUT" -name "PatientBillingPaymentHistory.java" 2>/dev/null | head -1)
if [[ -n "$PAYMENT_HISTORY_FILE" && -f "$PAYMENT_HISTORY_FILE" ]]; then
  if grep -qE "(private|protected)\s+Double\s+amountPaid" "$PAYMENT_HISTORY_FILE"; then
    pass "PatientBillingPaymentHistory.amountPaid uses Double (double format)"
  elif grep -qE "(private|protected)\s+double\s+amountPaid" "$PAYMENT_HISTORY_FILE"; then
    pass "PatientBillingPaymentHistory.amountPaid uses double primitive (double format)"
  elif grep -qE "amountPaid" "$PAYMENT_HISTORY_FILE"; then
    fail "PatientBillingPaymentHistory.amountPaid does not use Double for double format"
  fi
else
  fail "PatientBillingPaymentHistory.java not found in Java output"
fi

echo ""
echo "--- Checking int64 → Long mappings ---"
echo ""

# The OpenAPI spec uses int64 in endpoint response schemas (e.g., max-pages returns int64)
# Scan all Java files for any Long usage to verify int64 mapping exists if applicable
INT64_FOUND=false
if grep -rl "Long" "$JAVA_OUTPUT" &>/dev/null; then
  INT64_FOUND=true
  pass "Java output contains Long type (int64 mapping present)"
else
  # int64 fields may not exist in component schemas — check spec to confirm
  # If no int64 fields exist in schemas, this is not a failure
  INT64_IN_SCHEMAS=$(awk '
    /^  schemas:/ { in_schemas=1; next }
    in_schemas && /^  [^ ]/ && !/^  schemas:/ { in_schemas=0 }
    in_schemas && /format: int64/ { found=1 }
    END { print (found ? "yes" : "no") }
  ' "$SPEC_FILE")

  if [[ "$INT64_IN_SCHEMAS" == "yes" ]]; then
    fail "Java output missing Long type for int64 format fields defined in schemas"
  else
    pass "No int64 format fields in component schemas (Long not required)"
  fi
fi

echo ""
echo "--- Negative checks ---"
echo ""

# Verify that int32 fields are NOT mapped to Long or BigDecimal
if [[ -n "$LICENSE_FILE" && -f "$LICENSE_FILE" ]]; then
  if grep -qE "(private|protected)\s+(Long|BigDecimal)\s+usersLimit" "$LICENSE_FILE"; then
    fail "ApplicationLicense.usersLimit incorrectly uses Long/BigDecimal instead of Integer"
  else
    pass "ApplicationLicense.usersLimit does not incorrectly use Long/BigDecimal"
  fi
fi

# Verify that double fields are NOT mapped to BigDecimal or Integer
if [[ -n "$BILLING_ITEM_DTO_FILE" && -f "$BILLING_ITEM_DTO_FILE" ]]; then
  if grep -qE "(private|protected)\s+(BigDecimal|Integer|int)\s+itemCost" "$BILLING_ITEM_DTO_FILE"; then
    fail "BillingItemDTO.itemCost incorrectly uses BigDecimal/Integer instead of Double"
  else
    pass "BillingItemDTO.itemCost does not incorrectly use BigDecimal/Integer"
  fi
fi

echo ""

# --- Summary ---
echo "=== Summary ==="
if [[ $FAILURES -eq 0 ]]; then
  echo "All Java numeric format mapping checks passed."
  exit 0
else
  echo "$FAILURES check(s) failed." >&2
  exit 1
fi
