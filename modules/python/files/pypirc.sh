#!/bin/sh
set +x
set -eu
# Optional upload configuration, supplied at runtime only.
[ -z "${PYPI_UPLOAD_URL:-}" ] && exit 0
: "${HOME:?Set HOME}"
: "${PYPI_USER:?Set PYPI_USER}"
: "${PYPI_PASSWORD:?Set PYPI_PASSWORD}"
for value in "$PYPI_UPLOAD_URL" "$PYPI_USER" "$PYPI_PASSWORD"; do
    case "$value" in
        *'
'*) echo 'Upload configuration must not contain newlines.' >&2; exit 1 ;;
    esac
done
umask 077
file=$(mktemp "$HOME/.pypirc.XXXXXX")
trap 'rm -f "$file"' EXIT
printf '[distutils]\nindex-servers = custom\n\n[custom]\nrepository = %s\nusername = %s\npassword = %s\n' \
    "$PYPI_UPLOAD_URL" "$PYPI_USER" "$PYPI_PASSWORD" > "$file"
chmod 0600 "$file"
mv -f "$file" "$HOME/.pypirc"
