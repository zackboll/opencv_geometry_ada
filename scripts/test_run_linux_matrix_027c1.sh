#!/bin/bash
# Self-test for scripts/run_linux_matrix_027c1.sh: shows that its checks
# fail closed. Uses only a temporary directory; no OpenCV build, prefix or
# earlier log is modified.
#
#   scripts/test_run_linux_matrix_027c1.sh [--end-to-end]
#
# --end-to-end also runs the real runner with an unreachable Core repository
# and with a mismatched OpenCV prefix, and checks it exits nonzero and
# records a FAIL row. It needs the Task 026/027C1 OpenCV prefixes.
set -u -o pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
runner=$here/scripts/run_linux_matrix_027c1.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

MATRIX_RUNNER_LIB_ONLY=1
# shellcheck source=run_linux_matrix_027c1.sh
. "$runner"

passed=0; failed=0
expect() { # want(pass|fail) description command...
    local want=$1 what=$2 got
    shift 2
    if "$@" > "$tmp/out.txt" 2>&1; then got=pass; else got=fail; fi
    if [ "$got" = "$want" ]; then
        passed=$((passed + 1)); echo "ok   $what -> $got"
    else
        failed=$((failed + 1))
        echo "FAIL $what -> $got, wanted $want: $(cat "$tmp/out.txt")"
    fi
}

totals() { # file run ok fail err
    printf 'OK x\n\nTotal Tests Run:   %s\nSuccessful Tests:  %s\n' "$2" "$3" \
        > "$1"
    printf 'Failed Assertions: %s\nUnexpected Errors: %s\n' "$4" "$5" >> "$1"
}

# Commands.
expect pass "successful command" true
expect fail "command returning nonzero" false

# AUnit totals.
totals "$tmp/good.log" 542 542 0 0
expect pass "542/542, 0 failures, 0 errors" check_test_totals "$tmp/good.log" 542
expect fail "missing test log" check_test_totals "$tmp/absent.log" 542
: > "$tmp/empty.log"
expect fail "empty test log" check_test_totals "$tmp/empty.log" 542
head -n 3 "$tmp/good.log" > "$tmp/truncated.log"
expect fail "missing totals lines" check_test_totals "$tmp/truncated.log" 542
sed 's/Successful Tests:  542/Successful Tests:  many/' "$tmp/good.log" \
    > "$tmp/malformed.log"
expect fail "malformed total" check_test_totals "$tmp/malformed.log" 542
totals "$tmp/fail.log" 542 541 1 0
expect fail "one failed assertion" check_test_totals "$tmp/fail.log" 542
totals "$tmp/err.log" 542 541 0 1
expect fail "one unexpected error" check_test_totals "$tmp/err.log" 542
totals "$tmp/short.log" 541 541 0 0
expect fail "541 tests run, 542 expected" check_test_totals "$tmp/short.log" 542

# Generated configuration and loaded libraries.
p=$tmp/install-4.6.0
mkdir -p "$p/lib" "$tmp/other/lib" "$tmp/system/lib"
expect pass "config for this prefix" \
    check_config 4.6.0 "-L$p/lib" -lopencv_imgproc 4.6.0 "$p" imgproc
expect fail "config for another prefix" \
    check_config 4.6.0 "-L$tmp/other/lib" -lopencv_imgproc 4.6.0 "$p" imgproc
expect fail "config for another version" \
    check_config 4.10.0 "-L$p/lib" -lopencv_imgproc 4.6.0 "$p" imgproc
expect fail "config with OpenCV 4 module on OpenCV 5" \
    check_config 5.0.0 "-L$p/lib" -lopencv_imgproc 5.0.0 "$p" geometry
expect pass "libraries loaded from the prefix" check_loaded "$p" imgproc \
    "$p/lib/libopencv_core.so.4.6.0" "$p/lib/libopencv_imgproc.so.4.6.0"
expect fail "core loaded from another prefix" check_loaded "$p" imgproc \
    "$tmp/system/lib/libopencv_core.so.4.6.0" \
    "$p/lib/libopencv_imgproc.so.4.6.0"
expect fail "backend library not loaded" check_loaded "$p" imgproc \
    "$p/lib/libopencv_core.so.4.6.0"
expect fail "no OpenCV library loaded" check_loaded "$p" imgproc

# Sanitizer scan: zero findings must pass, not trip grep's status 1.
printf 'PASS everything\n' > "$tmp/clean.log"
expect pass "zero sanitizer findings" check_sanitizer "$tmp/clean.log"
printf '==1==ERROR: AddressSanitizer: heap-buffer-overflow\n' \
    > "$tmp/asan.log"
expect fail "AddressSanitizer report" \
    check_sanitizer "$tmp/clean.log" "$tmp/asan.log"
printf 'x.cpp:3:5: runtime error: signed integer overflow\n' \
    > "$tmp/ubsan.log"
expect fail "UBSan runtime error" check_sanitizer "$tmp/ubsan.log"
expect fail "unreadable sanitizer log" check_sanitizer "$tmp/absent.log"

# Native program inventory.
n=$tmp/native
mkdir -p "$n"
for f in a b c d; do : > "$n/$f.cpp"; done
expect pass "exact native program set" check_native_inventory "$n" a b c d
expect fail "expected native program missing" \
    check_native_inventory "$n" a b c d e
: > "$n/extra.cpp"
expect fail "unexpected native program" check_native_inventory "$n" a b c d

if [ "${1:-}" = --end-to-end ]; then
    expect fail "runner: Core clone fails" env WORK="$tmp/e2e" \
        CORE_REPO="$tmp/no-such-core" "$runner" 4.6.0 0.3.0
    expect pass "runner: FAIL row names clone_core" \
        grep -q ',FAIL,clone_core,' "$tmp/e2e/results-v2.csv"
    expect fail "runner: OpenCV 4.6.0 with the 4.14.0 prefix" env \
        WORK="$tmp/e2e" OPENCV_PREFIX=/var/tmp/geometry-026/install-4.14.0 \
        "$runner" 4.6.0 0.3.0
    expect pass "runner: FAIL row names pkg_config" \
        grep -q ',FAIL,pkg_config,' "$tmp/e2e/results-v2.csv"
    expect fail "runner: no PASS row recorded" \
        grep -q ',PASS,' "$tmp/e2e/results-v2.csv"
fi

echo "self-test: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
