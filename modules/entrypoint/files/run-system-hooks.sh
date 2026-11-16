#!/bin/sh
# Runs the executable files in /entrypoint.d as root, in lexicographic order
# and each with its own interpreter. Directories and non-executable files are
# skipped. The first hook that fails stops the run and its exit status is
# returned.
#
# Internal helper of /entrypoint.sh. When the container starts as a non-root
# user, /entrypoint.sh calls it through `sudo -n` (allowed without arguments
# by /etc/sudoers.d/entrypoint). It takes no arguments.
#
# VERBOSE_BOOT=yes prints the name of each hook; values are never printed.

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

log() {
    if [ "${VERBOSE_BOOT:-}" = "yes" ]; then
        echo "entrypoint: $*" >&2
    fi
}

run_dir() {
    for HOOK in "$1"/*; do
        [ -e "${HOOK}" ] || continue

        if [ -d "${HOOK}" ] || [ ! -x "${HOOK}" ]; then
            log "skipping ${HOOK}"
            continue
        fi

        log "running ${HOOK}"
        "${HOOK}"
        STATUS=$?
        if [ "${STATUS}" -ne 0 ]; then
            echo "entrypoint: ${HOOK} failed with status ${STATUS}" >&2
            return "${STATUS}"
        fi
    done

    return 0
}

main() {
    if [ "$#" -ne 0 ]; then
        echo "entrypoint: $0 takes no arguments" >&2
        return 2
    fi
    if [ "$(id -u)" -ne 0 ]; then
        echo "entrypoint: $0 must run as root" >&2
        return 1
    fi

    run_dir /entrypoint.d
}

main "$@"
