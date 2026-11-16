#!/bin/sh
set +x
set -eu
[ -z "${CREDENTIAL_FILE:-}" ] && exit 0
[ -f "$CREDENTIAL_FILE" ] && exit 0
umask 077
secret_tmp=$(mktemp "${CREDENTIAL_FILE}.XXXXXX")
trap 'rm -f "$secret_tmp"' EXIT
if [ -n "${CREDENTIAL_SOURCE_FILE:-}" ] && [ -f "$CREDENTIAL_SOURCE_FILE" ]; then
    cat "$CREDENTIAL_SOURCE_FILE" > "$secret_tmp"
elif [ -n "${CREDENTIAL_VALUE:-}" ]; then
    printf '%s\n' "$CREDENTIAL_VALUE" > "$secret_tmp"
elif [ -n "${CREDENTIAL_VAULT_PATH:-}" ]; then
    vault kv get -mount="${CREDENTIAL_VAULT_MOUNT:?Set CREDENTIAL_VAULT_MOUNT}" \
        -field="${CREDENTIAL_VAULT_FIELD:-password}" "$CREDENTIAL_VAULT_PATH" > "$secret_tmp"
else
    echo 'Provide CREDENTIAL_SOURCE_FILE, CREDENTIAL_VALUE or CREDENTIAL_VAULT_PATH.' >&2
    exit 1
fi
chmod 0600 "$secret_tmp"
mv -f "$secret_tmp" "$CREDENTIAL_FILE"
