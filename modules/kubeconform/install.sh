#!/bin/sh
set -eu
version=${KUBECONFORM_VERSION:-v0.6.7}
case "$version" in
    v[0-9]*) ;;
    *) echo 'Set KUBECONFORM_VERSION to a release tag beginning with v.' >&2; exit 1 ;;
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
work_dir=$(mktemp -d /tmp/kubeconform.XXXXXX)
trap 'rm -rf "$work_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
curl --fail --silent --show-error --location \
    "https://github.com/yannh/kubeconform/releases/download/$version/kubeconform-linux-amd64.tar.gz" \
    -o "$work_dir/release.tar.gz"
tar -xzf "$work_dir/release.tar.gz" -C "$work_dir" kubeconform
install -m 0755 "$work_dir/kubeconform" /usr/local/bin/kubeconform
