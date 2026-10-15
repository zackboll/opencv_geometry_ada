#!/bin/sh
# Verifies the redistribution notices of opencv_geometry.
#
# usage: check_notices.sh SOURCE_ROOT [GEOMETRY_PREFIX...]
#
# SOURCE_ROOT is a Geometry source tree:
#   - LICENSE must be the Apache License 2.0 text;
#   - every verbatim block of THIRD_PARTY_NOTICES must occur exactly once
#     and have the SHA-256 of the upstream text it reproduces, computed
#     from the upstream Git blobs that THIRD_PARTY_NOTICES names;
#   - the C++ sources that carry an upstream notice must contain it
#     verbatim.
# Each GEOMETRY_PREFIX is an installed Geometry prefix whose
# share/doc/opencv_geometry/LICENSE and THIRD_PARTY_NOTICES must be
# byte-identical to the source tree's.
set -eu

fail() {
    echo "error: $*" >&2
    exit 1
}

test "$#" -ge 1 || fail "usage: check_notices.sh SOURCE_ROOT [GEOMETRY_PREFIX...]"
root=$1
shift
notices=$root/THIRD_PARTY_NOTICES
for file in "$root/LICENSE" "$notices"; do
    test -f "$file" || fail "missing $file"
done

work=$(mktemp -d)
cleanup() {
    rm -f "$work/block" "$work/commented"
    rmdir "$work"
}
trap cleanup EXIT

digest() {
    sha256sum | cut -d ' ' -f 1
}

# The Apache License 2.0 text; OpenCV 4.12.0's LICENSE has the same bytes.
test "$(digest < "$root/LICENSE")" = \
    cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30 \
    || fail "LICENSE is not the Apache License 2.0 text"

# Writes the lines strictly between "----- BEGIN TITLE -----" and
# "----- END TITLE -----" to $work/block. Fails unless that block occurs
# exactly once and is closed.
block() { # title
    awk -v begin="----- BEGIN $1 -----" -v end="----- END $1 -----" '
        $0 == begin { opened++; inside = 1; next }
        $0 == end && inside { inside = 0; closed++; next }
        inside { print }
        END { exit !(opened == 1 && closed == 1) }' "$notices" \
        > "$work/block" \
        || fail "THIRD_PARTY_NOTICES needs exactly one closed \"$1\" block"
}

# True if the lines of NEEDLE occur consecutively in HAYSTACK.
occurs_in() { # needle haystack
    needle=$(tr '\n' '\001' < "$1")
    haystack=$(tr '\n' '\001' < "$2")
    case $haystack in
        *"$needle"*) return 0 ;;
    esac
    return 1
}

# Upstream digests: lines 1-40 of OpenCV 4.11.0/4.12.0
# modules/imgproc/src/geometry.cpp, 4.12.0 shapedescr.cpp and 4.13.0
# subdivision2d.cpp (all identical); OpenCV 4.13.0 COPYRIGHT; lines
# 256-269 of 4.11.0/4.12.0 geometry.cpp; 0xfaded/ellipse_demo LICENSE.
intel="OpenCV source file notice (Intel License Agreement)"
block "$intel"
test "$(digest < "$work/block")" = \
    07088edcd6834f7c52694c468a0d591ad1acd77867849434b92de57a27f78c87 \
    || fail "the \"$intel\" text differs from upstream"
for source in closest_ellipse_compat.hpp convex_intersection_compat.hpp \
    subdiv2d_compat_license.hpp
do
    occurs_in "$work/block" "$root/cpp/$source" \
        || fail "cpp/$source does not carry the \"$intel\" text verbatim"
done

block "OpenCV COPYRIGHT"
test "$(digest < "$work/block")" = \
    854538f426422b0f989a5e5b7641e5943753d10ef29ea54901dcd36039e43f58 \
    || fail "the OpenCV COPYRIGHT text differs from upstream"

orourke="Joseph O'Rourke notice"
block "$orourke"
test "$(digest < "$work/block")" = \
    e9e841991f22b00d685e286179165f877314a8301e428f4e79a7de7c25829987 \
    || fail "the \"$orourke\" text differs from upstream"
occurs_in "$work/block" "$root/cpp/convex_intersection_compat.hpp" \
    || fail "cpp/convex_intersection_compat.hpp does not carry the" \
        "\"$orourke\" text verbatim"

mit="MIT License (0xfaded/ellipse_demo)"
block "$mit"
test "$(digest < "$work/block")" = \
    d1f3530a0383628c968e495e1793f7c279917506ff9ccf977594b2d97bcfc757 \
    || fail "the \"$mit\" text differs from upstream"
# The C++ header carries it as // comments.
sed 's|^|// |; s|^// $|//|' "$work/block" > "$work/commented"
occurs_in "$work/commented" "$root/cpp/closest_ellipse_compat.hpp" \
    || fail "cpp/closest_ellipse_compat.hpp does not carry the \"$mit\"" \
        "text verbatim"

for prefix in "$@"; do
    for name in LICENSE THIRD_PARTY_NOTICES; do
        installed=$prefix/share/doc/opencv_geometry/$name
        test -f "$installed" || fail "missing installed notice: $installed"
        cmp -s "$root/$name" "$installed" \
            || fail "installed $name differs from the source: $installed"
    done
done
echo "PASS redistribution notices: source verbatim; $# installed prefix(es)"
