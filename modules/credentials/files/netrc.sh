#!/bin/sh
# Credentials are resolved only at runtime, never during the image build.
set +x
set -eu

[ -z "${NETRC_VAULT_PATH:-}" ] && exit 0
: "${NETRC_HOST:?Set NETRC_HOST}"
: "${NETRC_USER:?Set NETRC_USER}"
: "${HOME:?Set HOME for the container user}"
for value in "$NETRC_HOST" "$NETRC_USER"; do
    case "$value" in
        *[[:space:]]*) echo 'NETRC_HOST and NETRC_USER must not contain whitespace.' >&2; exit 1 ;;
    esac
done

password=$(vault kv get -mount="${NETRC_VAULT_MOUNT:?Set NETRC_VAULT_MOUNT}" \
    -field="${NETRC_VAULT_FIELD:-token}" "$NETRC_VAULT_PATH")
case "$password" in
    ''|*[[:space:]]*) echo 'The Vault credential must be a nonempty value without whitespace.' >&2; exit 1 ;;
esac

# Replace atomically so a failed lookup/write leaves the existing file intact.
umask 077
netrc_tmp=$(mktemp "$HOME/.netrc.XXXXXX")
trap 'rm -f "$netrc_tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'machine %s login %s password %s\n' "$NETRC_HOST" "$NETRC_USER" "$password" > "$netrc_tmp"
chmod 0600 "$netrc_tmp"
mv -f "$netrc_tmp" "$HOME/.netrc"
