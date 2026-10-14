#!/bin/sh
# Positive and negative controls for check_notices.sh. Each mutation is
# applied to a fresh copy of the notice-bearing files and must be
# rejected; the unmodified copy and its installed prefix must pass.
#
# usage: test_check_notices.sh [SOURCE_ROOT]   (default: this checkout)
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=${1:-$(CDPATH='' cd -- "$here/../.." && pwd)}
check=$here/check_notices.sh
work=$(mktemp -d)
trap 'rm -r "$work"' EXIT
failures=0
cases=0

# Copies the files check_notices.sh reads into a new source root and an
# installed prefix beside it.
fresh() { # name
    case_root=$work/$1/source
    case_prefix=$work/$1/prefix
    mkdir -p "$case_root/cpp" "$case_prefix/share/doc/opencv_geometry"
    cp "$root/LICENSE" "$root/THIRD_PARTY_NOTICES" "$case_root/"
    for source in closest_ellipse_compat.hpp convex_intersection_compat.hpp \
        subdiv2d_compat_license.hpp
    do
        cp "$root/cpp/$source" "$case_root/cpp/"
    done
    cp "$root/LICENSE" "$root/THIRD_PARTY_NOTICES" \
        "$case_prefix/share/doc/opencv_geometry/"
}

# Replaces the first line matching PATTERN in FILE with REPLACEMENT.
replace_first() { # file pattern replacement
    awk -v pattern="$2" -v replacement="$3" '
        !done && index($0, pattern) { print replacement; done = 1; next }
        { print }
        END { exit !done }' "$1" > "$1.new" \
        || { echo "control setup: '$2' not found in $1" >&2; exit 2; }
    mv "$1.new" "$1"
}

# Deletes the first line matching PATTERN in FILE.
delete_first() { # file pattern
    awk -v pattern="$2" '
        !done && index($0, pattern) { done = 1; next }
        { print }
        END { exit !done }' "$1" > "$1.new" \
        || { echo "control setup: '$2' not found in $1" >&2; exit 2; }
    mv "$1.new" "$1"
}

expect() { # pass|reject name
    cases=$((cases + 1))
    if sh "$check" "$case_root" "$case_prefix" > "$work/$2.log" 2>&1; then
        result=pass
    else
        result=reject
    fi
    if [ "$result" = "$1" ]; then
        echo "ok   $2 ($result): $(tail -n 1 "$work/$2.log")"
    else
        echo "FAIL $2: expected $1, got $result"
        sed 's/^/     /' "$work/$2.log"
        failures=$((failures + 1))
    fi
}

fresh unmodified
expect pass unmodified

fresh intel-apostrophe
replace_first "$case_root/THIRD_PARTY_NOTICES" \
    "//   * Redistribution's of source code must retain" \
    "//   * Redistributions of source code must retain the above copyright notice,"
expect reject intel-apostrophe

fresh intel-disclaimer-line
delete_first "$case_root/THIRD_PARTY_NOTICES" \
    "// the use of this software, even if advised"
expect reject intel-disclaimer-line

fresh copyright-holder
delete_first "$case_root/THIRD_PARTY_NOTICES" "Willow Garage"
expect reject copyright-holder

fresh orourke-condition
replace_first "$case_root/THIRD_PARTY_NOTICES" " not removed." " not altered."
expect reject orourke-condition

fresh mit-permission
delete_first "$case_root/THIRD_PARTY_NOTICES" \
    "copies or substantial portions of the Software."
expect reject mit-permission

fresh duplicate-block
printf '%s\n%s\n' "----- BEGIN Joseph O'Rourke notice -----" \
    "----- END Joseph O'Rourke notice -----" \
    >> "$case_root/THIRD_PARTY_NOTICES"
expect reject duplicate-block

fresh unclosed-block
delete_first "$case_root/THIRD_PARTY_NOTICES" \
    "----- END MIT License (0xfaded/ellipse_demo) -----"
expect reject unclosed-block

fresh paraphrased-source-header
replace_first "$case_root/cpp/closest_ellipse_compat.hpp" \
    "//   * Redistribution's in binary form must reproduce" \
    "//   * Redistributions in binary form must reproduce the above copyright notice,"
expect reject paraphrased-source-header

fresh subdiv-header-without-notice
delete_first "$case_root/cpp/subdiv2d_compat_license.hpp" \
    "Intel License Agreement"
expect reject subdiv-header-without-notice

fresh convex-header-without-orourke
delete_first "$case_root/cpp/convex_intersection_compat.hpp" \
    "This code is Copyright 1997 by Joseph O'Rourke."
expect reject convex-header-without-orourke

fresh closest-header-without-mit
delete_first "$case_root/cpp/closest_ellipse_compat.hpp" \
    "// Copyright (c) 2017 Carl Chatfield"
expect reject closest-header-without-mit

fresh license-text
replace_first "$case_root/LICENSE" "Version 2.0, January 2004" \
    "                           Version 2.0"
cp "$case_root/LICENSE" "$case_prefix/share/doc/opencv_geometry/LICENSE"
expect reject license-text

fresh installed-license-missing
rm "$case_prefix/share/doc/opencv_geometry/LICENSE"
expect reject installed-license-missing

fresh installed-notices-missing
rm "$case_prefix/share/doc/opencv_geometry/THIRD_PARTY_NOTICES"
expect reject installed-notices-missing

fresh installed-notices-stale
delete_first "$case_prefix/share/doc/opencv_geometry/THIRD_PARTY_NOTICES" \
    "Willow Garage"
expect reject installed-notices-stale

echo "$cases cases, $failures failed"
test "$failures" -eq 0
