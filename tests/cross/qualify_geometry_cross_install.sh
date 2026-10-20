#!/bin/sh
# Same explicit arguments as cross_install_geometry.sh. Requires a fresh
# Geometry prefix; reuses installed Core, never builds or moves Core.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
exec sh "$root/scripts/cross_install_geometry.sh" --qualify "$@"