#!/bin/sh
set -eu
version=${PYTHONMAJORVERSION:-3}
case "$version" in
    3|3.[0-9]|3.[0-9][0-9]) ;;
    *) echo "Unsupported Python version: $version" >&2; exit 1 ;;
esac
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y "python$version-pip"
microdnf clean all
# pip uses its normal defaults. Supply PIP_INDEX_URL when using another index.
mkdir -p /entrypoint.user.d
install -m 0755 /tmp/artifacts/pypirc.sh /entrypoint.user.d/50-python-pypirc.sh
