#!/bin/sh
# Bootstrap only; reuse the fail-closed production implementation.
set -eu
exec python3 "$(dirname -- "$0")/cross_install_geometry.py" "$@"