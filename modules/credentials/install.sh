#!/bin/sh
set -eu
# SSH certificate hooks need ssh-keygen; Bash is their interpreter.
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y openssh-clients bash
microdnf clean all
mkdir -p /entrypoint.user.d
install -m 0755 /tmp/artifacts/credentials-netrc.sh /entrypoint.user.d/55-credentials-netrc.sh
install -m 0755 /tmp/artifacts/credentials-secret-file.sh /entrypoint.user.d/60-credentials-secret-file.sh
install -m 0755 /tmp/artifacts/credentials-ssh-vault-ca.sh /entrypoint.user.d/70-ssh-vault-ca.sh
install -m 0755 /tmp/artifacts/credentials-entrypoint.sh /credentials-entrypoint.sh
