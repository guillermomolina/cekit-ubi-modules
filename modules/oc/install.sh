#!/bin/sh
set -eu
version=${OC_VERSION:-4.21.17}
case "$version" in
    [0-9]*) ;;
    *) echo 'Set OC_VERSION to an OpenShift release number.' >&2; exit 1 ;;
esac
case "$version" in
    *[!a-zA-Z0-9.+-]*) echo 'Invalid OpenShift release version.' >&2; exit 1 ;;
esac
if [ "$(rpm --eval '%{_arch}')" != x86_64 ]; then
    echo 'This module installs the Linux amd64 release.' >&2
    exit 1
fi
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y tar gzip bash-completion
microdnf clean all
work_dir=$(mktemp -d /tmp/oc.XXXXXX)
trap 'rm -rf "$work_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
curl --fail --silent --show-error --location \
    "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$version/openshift-client-linux-$version.tar.gz" \
    -o "$work_dir/release.tar.gz"
tar -xzf "$work_dir/release.tar.gz" -C "$work_dir" oc
install -m 0755 "$work_dir/oc" /usr/bin/oc
mkdir -p /etc/bash_completion.d
oc completion bash > /etc/bash_completion.d/oc
chmod 0644 /etc/bash_completion.d/oc
