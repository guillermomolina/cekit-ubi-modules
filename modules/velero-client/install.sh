#!/bin/sh
set -eu
version=${VELERO_VERSION:-1.16.2}
case "$version" in
    ''|*[!0-9.]*) echo 'Set VELERO_VERSION to a numeric release without v.' >&2; exit 1 ;;
esac
case "$(rpm --eval '%{_arch}')" in
    x86_64) arch=amd64 ;;
    aarch64) arch=arm64 ;;
    *) echo 'Velero supports x86_64 and aarch64 in this module.' >&2; exit 1 ;;
esac
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y tar gzip bash-completion
microdnf clean all
work_dir=$(mktemp -d /tmp/velero.XXXXXX)
trap 'rm -rf "$work_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
archive="velero-v$version-linux-$arch"
curl --fail --silent --show-error --location \
    "https://github.com/vmware-tanzu/velero/releases/download/v$version/$archive.tar.gz" \
    -o "$work_dir/velero.tar.gz"
tar -xzf "$work_dir/velero.tar.gz" -C "$work_dir" "$archive/velero"
install -m 0755 "$work_dir/$archive/velero" /usr/bin/velero
mkdir -p /etc/bash_completion.d
velero completion bash > /etc/bash_completion.d/velero
velero version --client-only
