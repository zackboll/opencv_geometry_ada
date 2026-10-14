#!/bin/sh
# Opt-in, fail-closed AArch64 Linux cross configuration and build of the
# clean HEAD of this checkout in a new, disposable workspace. Every target
# input is explicit; see scripts/cross_geometry.py for the contract.
#
# usage: cross_build_geometry.sh check
#        cross_build_geometry.sh --prepare|--build ABSOLUTE_WORKSPACE
set -eu
exec python3 "$(dirname -- "$0")/cross_geometry.py" "$@"
