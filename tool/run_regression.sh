#!/usr/bin/env bash
# T-09E full regression: run every integration script on the real Windows
# engine, one file at a time (each file is its own evidence run), and keep a
# per-file log plus a combined summary.
#
# Usage: tool/run_regression.sh [ticket-tag]
set -u

cd "$(dirname "$0")/.." || exit 1
tag="${1:-t09e}"
out="evidence/${tag}/regression"
mkdir -p "$out"

files=(
  t03_flow_test
  t04_assets_test
  t05_stats_test
  t09a_reskin_test
  t09b_detail_flow_test
  t09c_motion_test
  t09c2_base_motion_test
  t09d_edit_flow_test
  t09e_brand_test
)

summary="$out/.regression_summary.txt"
: >"$summary"

fail=0
for f in "${files[@]}"; do
  printf '=== %s === ' "$f"
  flutter test "integration_test/${f}.dart" -d windows >"$out/${f}.log" 2>&1
  code=$?
  tail_line=$(grep -E 'All tests passed|Some tests failed' "$out/${f}.log" | tail -1)
  printf 'exit=%s %s\n' "$code" "$tail_line"
  printf '%s  exit=%s  %s\n' "$f" "$code" "$tail_line" >>"$summary"
  [ "$code" -ne 0 ] && fail=$((fail + 1))
done

printf '\nfailures=%s of %s\n' "$fail" "${#files[@]}"
cat "$summary"
exit "$fail"
