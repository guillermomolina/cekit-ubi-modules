#!/bin/sh
set -eu
# Optional: credentials must be available before this user hook runs.
[ -z "${GIT_UPDATE_DIR:-}" ] && exit 0
[ "${GIT_UPDATE:-yes}" = no ] && exit 0
export GIT_TERMINAL_PROMPT=0
git -C "$GIT_UPDATE_DIR" pull --ff-only
