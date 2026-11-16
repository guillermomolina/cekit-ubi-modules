#!/bin/sh

main() {
    # The python module dependency provides pip and repository configuration.
    command -v pip >/dev/null 2>&1 || {
        echo "The ansible module requires Python/pip; install the python module first or use a Python base image." >&2
        return 1
    }

    microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y \
        openssh-clients || return 1
    microdnf clean all || return 1

    # Intentional word splitting: PIP_INSTALL_OPTIONS contains separate flags,
    # following the existing Python image contract.
    pip install ${PIP_INSTALL_OPTIONS:---root-user-action=ignore --disable-pip-version-check --no-cache-dir} \
        -r /tmp/artifacts/ansible-requirements.txt || return 1
    rm -f /tmp/artifacts/ansible-requirements.txt || return 1

    install -m 0755 /tmp/artifacts/ansible-entrypoint.sh /ansible-entrypoint.sh || return 1
    mkdir -p /entrypoint.user.d || return 1
    install -m 0755 /tmp/artifacts/ansible-update.sh /entrypoint.user.d/80-ansible-update.sh || return 1
    echo "ANSIBLE_FEATURE_INSTALL=PASS"
}

main "$@"
