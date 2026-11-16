#!/bin/sh
set -eu

USER_NAME=${USER_NAME:-user}
USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}
USER_GROUP=${USER_GROUP:-$USER_NAME}
USER_HOME=${USER_HOME:-/home/$USER_NAME}
USER_SHELL=${USER_SHELL:-/bin/bash}
USER_SUDO=${USER_SUDO:-no}

# Validate values before writing passwd/group or installing packages.
for name in "$USER_NAME" "$USER_GROUP"; do
    case "$name" in
        ''|[!a-z_]*|*[!a-z0-9_-]*) echo "Invalid user/group name: $name" >&2; exit 1 ;;
    esac
done
for number in "$USER_UID" "$USER_GID"; do
    case "$number" in
        ''|0*|*[!0-9]*) echo "UID/GID must be positive integers: $number" >&2; exit 1 ;;
    esac
done
for path in "$USER_HOME" "$USER_SHELL"; do
    case "$path" in
        /|*[!a-zA-Z0-9_./-]*) echo "Invalid home/shell path: $path" >&2; exit 1 ;;
        /*) ;;
        *) echo "Home and shell must be absolute paths." >&2; exit 1 ;;
    esac
done
case "$USER_SUDO" in
    yes|no) ;;
    *) echo 'USER_SUDO must be yes or no.' >&2; exit 1 ;;
esac

if getent passwd "$USER_NAME" >/dev/null || getent passwd "$USER_UID" >/dev/null ||
   getent group "$USER_GROUP" >/dev/null || getent group "$USER_GID" >/dev/null; then
    echo 'User/group name or UID/GID already exists.' >&2
    exit 1
fi

if [ "$USER_SHELL" = /bin/bash ] && [ ! -x "$USER_SHELL" ]; then
    microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y bash
    microdnf clean all
fi
if [ ! -x "$USER_SHELL" ]; then
    echo "Shell is not executable: $USER_SHELL" >&2
    exit 1
fi
if [ "$USER_SUDO" = yes ]; then
    microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y sudo
    microdnf clean all
fi

# Write accounts directly to avoid gshadow operations in rootless Buildah.
# The account has no usable password.
printf '%s:x:%s:\n' "$USER_GROUP" "$USER_GID" >> /etc/group
printf '%s:!:%s:%s:%s:%s:%s\n' "$USER_NAME" "$USER_UID" "$USER_GID" \
    "$USER_NAME" "$USER_HOME" "$USER_SHELL" >> /etc/passwd
mkdir -p "$USER_HOME"
chown "$USER_UID:$USER_GID" "$USER_HOME"
chmod 0755 "$USER_HOME"

if [ "$USER_SUDO" = yes ]; then
    mkdir -p /etc/sudoers.d
    SUDOERS="/etc/sudoers.d/user-$USER_NAME"
    printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$USER_NAME" > "$SUDOERS"
    chown root:root "$SUDOERS"
    chmod 0440 "$SUDOERS"
    visudo -cf "$SUDOERS"
fi

echo 'USER_MODULE_INSTALL=PASS'
