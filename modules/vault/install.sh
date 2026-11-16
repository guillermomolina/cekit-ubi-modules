#!/bin/sh

main() {
    case "${VAULT_VERSION:-}" in
        ""|*[!0-9a-zA-Z.+-]*)
            echo "Set VAULT_VERSION to the Vault release to install." >&2
            return 1
            ;;
    esac

    # Preserve unzip when it was already installed by the base image.
    REMOVE_UNZIP=no
    if ! rpm -q unzip >/dev/null 2>&1; then
        microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y unzip || return 1
        REMOVE_UNZIP=yes
    fi

    ARCHIVE=$(mktemp /tmp/vault.XXXXXX.zip) || return 1
    curl --fail --show-error --silent --location \
        -o "${ARCHIVE}" \
        "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" || {
        rm -f "${ARCHIVE}"
        return 1
    }
    unzip -o "${ARCHIVE}" vault -d /usr/bin || {
        rm -f "${ARCHIVE}"
        return 1
    }
    rm -f "${ARCHIVE}" || return 1
    chmod 0755 /usr/bin/vault || return 1

    if [ "${REMOVE_UNZIP}" = yes ]; then
        microdnf remove -y unzip || return 1
    fi
    microdnf clean all || return 1

    echo "VAULT_FEATURE_INSTALL=PASS"
}

main "$@"
