#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Modified adaptation of podman-container-tools/image_build; see NOTICE.md.
set -eu
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y skopeo fuse-overlayfs cpp sqlite
microdnf clean all

# The user dependency creates the account; defaults match the user module.
account=${USER_NAME:-user}
account_uid=${USER_UID:-1000}
account_gid=${USER_GID:-1000}
account_home=${USER_HOME:-/home/$account}
if [ "$account_uid" -ge 65535 ] || [ "$account_gid" -ge 65535 ]; then
    echo 'Nested container storage requires USER_UID and USER_GID below 65535.' >&2
    exit 1
fi
# Keep the original ranges inside the outer container's subordinate mapping.
for file in /etc/subuid /etc/subgid; do
    account_id=$account_uid
    [ "$file" != /etc/subgid ] || account_id=$account_gid
    if ! grep -q '^root:' "$file" 2>/dev/null; then
        printf '%s\n' 'root:1:65535' >> "$file"
    fi
    if ! grep -q "^${account}:" "$file" 2>/dev/null; then
        if [ "$account_id" -gt 1 ]; then
            printf '%s:1:%s\n' "$account" "$((account_id - 1))" >> "$file"
        fi
        printf '%s:%s:%s\n' "$account" "$((account_id + 1))" "$((65535 - account_id))" >> "$file"
    fi
    chmod 0644 "$file"
done

cat > /etc/containers/storage.conf <<'CONFIG'
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"
[storage.options]
additionalimagestores = ["/var/lib/shared"]
[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
mountopt = "nodev,fsync=0"
CONFIG
chmod 0644 /etc/containers/storage.conf

mkdir -p "$account_home/.local/share/containers" "$account_home/.config/containers"
sed -e 's|^graphroot|#graphroot|g' \
    -e 's|^runroot|#runroot|g' \
    /etc/containers/storage.conf > "$account_home/.config/containers/storage.conf"
chown -R "$account_uid:$account_gid" "$account_home/.config" "$account_home/.local"
for driver in overlay vfs; do
    mkdir -p "/var/lib/shared/$driver-images" "/var/lib/shared/$driver-layers"
    touch "/var/lib/shared/$driver-images/images.lock" "/var/lib/shared/$driver-layers/layers.lock"
done
