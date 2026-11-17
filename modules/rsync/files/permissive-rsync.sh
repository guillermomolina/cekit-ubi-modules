#!/usr/bin/env bash

REAL_RSYNC=/usr/bin/rsync
IGNOREEXIT=24
IGNOREOUT='^(file has vanished: |rsync warning: some files vanished before they could be transferred)'

set -o pipefail

# This filters stderr without merging it with stdout:
{ $REAL_RSYNC "${@}" 2>&1 1>&3 3>&- | grep -E -v "$IGNOREOUT"; ret=${PIPESTATUS[0]}; } 3>&1 1>&2

if [[ $ret == $IGNOREEXIT ]]; then
    ret=0
fi

exit $ret
