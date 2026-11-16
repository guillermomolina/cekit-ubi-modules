#!/bin/sh

main() {
    EPEL_VERSION="${EPEL_MAJOR_VERSION:-auto}"
    if [ "${EPEL_VERSION}" = auto ]; then
        EPEL_VERSION=$(rpm --eval '%{rhel}') || return 1
    fi

    case "${EPEL_VERSION}" in
        8|9|10) ;;
        *)
            echo "Unsupported EPEL major version: ${EPEL_VERSION}; set EPEL_MAJOR_VERSION to 8, 9 or 10." >&2
            return 1
            ;;
    esac

    rpm -ivh "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${EPEL_VERSION}.noarch.rpm" || return 1

    echo "EPEL_FEATURE_INSTALL=PASS"
}

main "$@"
