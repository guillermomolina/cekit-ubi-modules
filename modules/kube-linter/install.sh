#!/bin/sh
set -eu
version=${KUBE_LINTER_VERSION:-v0.7.2}
case "$version" in
    v[0-9]*) ;;
    *) echo 'Set KUBE_LINTER_VERSION to a release tag beginning with v.' >&2; exit 1 ;;
esac
case "$version" in
    *[!a-zA-Z0-9.+-]*) echo 'Invalid release tag.' >&2; exit 1 ;;
esac
if [ "$(rpm --eval '%{_arch}')" != x86_64 ]; then
    echo 'This module installs the Linux amd64 release.' >&2
    exit 1
fi
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y tar gzip
microdnf clean all
work_dir=$(mktemp -d /tmp/kube-linter.XXXXXX)
trap 'rm -rf "$work_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
curl --fail --silent --show-error --location \
    "https://github.com/stackrox/kube-linter/releases/download/$version/kube-linter-linux.tar.gz" \
    -o "$work_dir/release.tar.gz"
tar -xzf "$work_dir/release.tar.gz" -C "$work_dir" kube-linter
install -m 0755 "$work_dir/kube-linter" /usr/local/bin/kube-linter
