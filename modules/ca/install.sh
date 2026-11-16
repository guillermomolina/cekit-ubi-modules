#!/bin/sh
set -eu
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y ca-certificates
microdnf clean all
install -m 0644 /tmp/artifacts/custom-ca.crt /etc/pki/ca-trust/source/anchors/custom-ca.crt
update-ca-trust
