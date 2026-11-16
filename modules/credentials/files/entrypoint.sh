#!/bin/sh
set +x
set -eu
if { [ -n "${NETRC_VAULT_PATH:-}" ] || [ -n "${CREDENTIAL_VAULT_PATH:-}" ]; } && ! vault token lookup >/dev/null 2>&1; then
    role_id="${VAULT_APPROLE_ROLE_ID:-}"
    secret_id="${VAULT_APPROLE_SECRET_ID:-}"
    if [ -z "$role_id" ] && [ -f /vault/secrets/role_id ]; then
        role_id=$(cat /vault/secrets/role_id)
    fi
    if [ -z "$secret_id" ] && [ -f /vault/secrets/secret_id ]; then
        secret_id=$(cat /vault/secrets/secret_id)
    fi
    if [ -n "$role_id" ] && [ -n "$secret_id" ]; then
        VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id="$role_id" secret_id="$secret_id")
        export VAULT_TOKEN
    else
        echo 'No Vault session. Provide VAULT_TOKEN or AppRole credentials; for local runs, log in to Vault on the host first.' >&2
        exit 1
    fi
fi
exec /entrypoint.sh "$@"
