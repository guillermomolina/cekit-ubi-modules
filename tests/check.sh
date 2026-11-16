#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."

for file in modules/*/*.sh modules/*/files/*; do
    [ -f "$file" ] || continue
    read -r first_line < "$file"
    case "$first_line" in
        '#!'*bash*) bash -n "$file" ;;
        '#!'*) sh -n "$file" ;;
    esac
done

for image in images/*; do
    if [ "$image" = images/custom-ca ] && [ ! -f "$image/private/custom-ca.crt" ]; then
        echo 'Skipping custom-ca: supply your own private/custom-ca.crt to check it.'
        continue
    fi
    echo "Checking $image"
    (cd "$image" && "${CEKIT:-cekit}" build --dry-run buildah)
done
