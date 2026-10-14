#!/bin/sh
# Local two-stage Debian 12 GNAT 12 installed-consumer qualification, the
# same stages as .github/workflows/debian12-installed-consumers.yml.
#
# The preparation container receives read-only Geometry, Core and AUnit
# sources. The consumer container receives only the payload: no source
# checkout and no Alire.
#
# Inputs:
#   QUALIFICATION_EVIDENCE  absolute evidence directory; must not exist
#   GNAT12_CORE_ROOT        clean opencv_core Git clone (not a worktree)
#   GNAT12_CORE_COMMIT      Core commit expected at GNAT12_CORE_ROOT
#   GNAT12_AUNIT_ROOT       unpacked AUnit 26.0.0 sources
#   GNAT12_SOURCE_ROOT      clean Geometry Git clone (default: this one)
#   CONTAINER_ENGINE        podman (default) or docker
#   QUALIFICATION_IMAGE     image built from tests/gnat12/Containerfile
#                           (default: built and tagged here)
set -eu

fail() {
    echo "error: $*" >&2
    exit 1
}

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=${GNAT12_SOURCE_ROOT:-$(CDPATH='' cd -- "$here/../.." && pwd)}
evidence=${QUALIFICATION_EVIDENCE:?set QUALIFICATION_EVIDENCE}
core=${GNAT12_CORE_ROOT:?set GNAT12_CORE_ROOT}
core_commit=${GNAT12_CORE_COMMIT:?set GNAT12_CORE_COMMIT}
aunit=${GNAT12_AUNIT_ROOT:?set GNAT12_AUNIT_ROOT}
engine=${CONTAINER_ENGINE:-podman}
image=${QUALIFICATION_IMAGE:-localhost/opencv-geometry-debian12-gnat12:local}

case "$evidence" in /*) ;; *) fail "absolute evidence path required" ;; esac
test ! -e "$evidence" || fail "evidence directory already exists: $evidence"
for repo in "$root" "$core"; do
    test -d "$repo/.git" || fail "a self-contained Git clone is required: $repo"
done

if [ -z "${QUALIFICATION_IMAGE:-}" ]; then
    "$engine" build -t "$image" -f "$root/tests/gnat12/Containerfile" \
        "$root/tests/gnat12" >&2
fi
mkdir -p "$evidence/consumer"
{
    echo "geometry: $(git -C "$root" rev-parse HEAD)"
    echo "core: $(git -C "$core" rev-parse HEAD)"
    echo "image: $("$engine" image inspect "$image" --format '{{.Id}}')"
    echo "engine: $("$engine" --version)"
} > "$evidence/identity.txt"

"$engine" run --rm \
    -v "$root:/sources/geometry:ro" \
    -v "$core:/sources/core:ro" \
    -v "$aunit:/sources/aunit:ro" \
    -v "$evidence:/evidence" \
    -e GNAT12_SOURCE_ROOT=/sources/geometry \
    -e GNAT12_CORE_ROOT=/sources/core \
    -e "GNAT12_CORE_COMMIT=$core_commit" \
    -e GNAT12_AUNIT_ROOT=/sources/aunit \
    -e GNAT12_WORK=/evidence/work \
    -e CONSUMER_PAYLOAD=/evidence/payload \
    -e CONSUMER_LOGS=/evidence/prepare-logs \
    "$image" sh /sources/geometry/tests/installed_consumers/prepare.sh \
    > "$evidence/prepare.log" 2>&1 \
    || fail "preparation failed; see $evidence/prepare.log"

"$engine" run --rm \
    -v "$evidence/payload:/evidence/payload" \
    -v "$evidence/consumer:/consumer" \
    "$image" sh /evidence/payload/consume.sh /evidence/payload /consumer/logs \
    > "$evidence/consume.log" 2>&1 \
    || fail "consumer qualification failed; see $evidence/consume.log"

tail -n 1 "$evidence/prepare.log"
tail -n 1 "$evidence/consume.log"
