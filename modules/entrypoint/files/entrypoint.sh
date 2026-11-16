#!/bin/sh
# Container entrypoint. In order:
#   1. runs the system hooks in /entrypoint.d as root, through
#      /run-system-hooks.sh (directly when already root, otherwise with
#      `sudo -n`, allowed by /etc/sudoers.d/entrypoint);
#   2. runs the user hooks in /entrypoint.user.d as the current user;
#   3. replaces itself with the command passed as arguments, if any
#      (https://github.com/docker-library/official-images#consistency).
#
# Hooks run in lexicographic order, each with its own interpreter;
# directories and non-executable files are skipped. The first hook that fails
# stops the start and its exit status is returned; the command is not run.
#
# VERBOSE_BOOT=yes prints the name of each hook; values are never printed.

SYSTEM_HOOKS=/run-system-hooks.sh

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

# True when the directory has at least one hook that would run.
has_hooks() {
    for HOOK in "$1"/*; do
        if [ -f "${HOOK}" ] && [ -x "${HOOK}" ]; then
            return 0
        fi
    done
    return 1
}

run_system_hooks() {
    if [ "$(id -u)" -eq 0 ]; then
        "${SYSTEM_HOOKS}"
        return
    fi

    has_hooks /entrypoint.d || return 0

    if ! command -v sudo >/dev/null 2>&1; then
        echo "entrypoint: the hooks in /entrypoint.d need root; start the container as root or install sudo" >&2
        return 1
    fi
    sudo -n "${SYSTEM_HOOKS}"
}

main() {
    run_system_hooks || return
    run_dir /entrypoint.user.d || return

    if [ "$#" -gt 0 ]; then
        exec "$@"
    fi
    return 0
}

main "$@"
