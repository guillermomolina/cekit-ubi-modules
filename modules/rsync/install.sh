#!/bin/sh
set -eu
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y rsync bash grep
microdnf clean all
install -m 0755 /tmp/artifacts/permissive-rsync.sh /usr/bin/permissive-rsync.sh
