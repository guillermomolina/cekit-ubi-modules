#!/bin/sh
set -eu
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y git-core
microdnf clean all
mkdir -p /entrypoint.user.d
install -m 0755 /tmp/artifacts/git-update.sh /entrypoint.user.d/75-git-update.sh
