#!/bin/sh
# Distinct GNAT Pro 25.2 track: never emits GNAT12 qualification labels.
set -eu
test "$#" -eq 1 || { echo 'usage: qualify_adacore25_yocto.sh EVIDENCE' >&2; exit 1; }
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
evidence=$1
case "$evidence" in /?*) ;; *) exit 1 ;; esac
test ! -e "$evidence"
mkdir -p "$evidence/logs"
python3 "$here/verify_adacore25.py" \
    "${QUALIFY_YOCTO_INSTALLER:?set official SDK installer}" \
    "${QUALIFY_YOCTO_SDK:?set installed official SDK root}" \
    > "$evidence/logs/claims-25.2.json" \
    2> "$evidence/logs/claims-25.2.err" || exit 1
export QUALIFY_TRACK=adacore25
sh "$here/qualify_target.sh" "$evidence"
printf '%s\n' 'ADACORE_GNAT_PRO_25_2_CROSS_QUALIFIED' \
    'YOCTO_SCARTHGAP_CROSS_QUALIFIED' >> "$evidence/dispositions.txt"
cat "$evidence/dispositions.txt"