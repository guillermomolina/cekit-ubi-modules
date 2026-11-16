#!/bin/sh

SUDOERS=/etc/sudoers.d/entrypoint

install_sudoers() {
    # Written even when sudo is not installed: it stays inert until the image
    # installs sudo. Allows any user to run /run-system-hooks.sh as root,
    # without arguments only.
    mkdir -p /etc/sudoers.d || return 1
    printf '%s\n' 'ALL ALL=(root) NOPASSWD: /run-system-hooks.sh ""' > "${SUDOERS}" || return 1
    chown root:root "${SUDOERS}" && chmod 0440 "${SUDOERS}" || return 1

    if command -v visudo >/dev/null 2>&1; then
        visudo -cf "${SUDOERS}" >/dev/null || return 1
    fi
}

main() {
    mkdir -p /entrypoint.d /entrypoint.user.d || return 1
    chmod 0755 /entrypoint.d /entrypoint.user.d || return 1

    for SCRIPT in entrypoint.sh run-system-hooks.sh; do
        cp "/tmp/artifacts/${SCRIPT}" "/${SCRIPT}" || return 1
        chown root:root "/${SCRIPT}" && chmod 0755 "/${SCRIPT}" || return 1
    done

    install_sudoers || return 1

    echo "ENTRYPOINT_FEATURE_INSTALL=PASS"
}

main "$@"
