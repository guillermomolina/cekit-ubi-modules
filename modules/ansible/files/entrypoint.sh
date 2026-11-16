#!/bin/sh
set +x
set -eu
# Project features are optional; plain Ansible images need no configuration.
if [ -n "${ANSIBLE_PROJECT_DIR:-}" ]; then
    # Inventory selection belongs to the calling image or runtime environment.
    : "${ANSIBLE_INVENTORY:=}"
    export ANSIBLE_PRIVATE_KEY_FILE="${ANSIBLE_PRIVATE_KEY_FILE:-${VAULT_SSH_KEY:-${HOME}/.ssh/id_ed25519}}"
fi
if [ -x /credentials-entrypoint.sh ]; then
    exec /credentials-entrypoint.sh "$@"
fi
exec /entrypoint.sh "$@"
