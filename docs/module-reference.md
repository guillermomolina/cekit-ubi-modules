# Module reference

[README](../README.md) · [Tutorial](tutorial.md) · [Recipes](recipes.md)

## Descriptor settings versus runtime settings

Build arguments appear under `args` in an image descriptor and are available to
installation scripts. Runtime variables belong under `envs` or are passed to
`podman run --env`. They are not interchangeable: passing a runtime variable
cannot change a package already installed in an image.

```yaml
args:
  - name: JAVA_MAJOR_VERSION
    value: "21"
envs:
  - name: VERBOSE_BOOT
    value: "yes"
```

Unless noted below, installation targets UBI minimal with `microdnf`. Package
versions come from the enabled RPM repositories. A module need not appear in
the image's install list if another selected module declares it as a dependency.

## Accounts and startup

Start with the tutorial's [build and startup lifecycle](tutorial.md#5-run-python-without-root)
and [combined system/user hook example](tutorial.md#combining-system-hooks-and-a-non-root-user).
Module dependencies order installation during the build; hook filenames order
execution at each container start.

### `user`

No module dependencies. It creates an account without a usable password and
fails if its username, UID, group name or GID already exists.

| Build argument | Default |
|---|---|
| `USER_NAME` | `user` |
| `USER_UID`, `USER_GID` | `1000` |
| `USER_GROUP` | Value of `USER_NAME` |
| `USER_HOME` | `/home/<USER_NAME>` |
| `USER_SHELL` | `/bin/bash` |
| `USER_SUDO` | `no` |

Bash is installed if selected and missing. Other shells must already exist.
`USER_SUDO=yes` installs sudo and grants unrestricted passwordless sudo to the
account. The module does not set image `run.user`, `run.workdir` or `HOME`.
See [python-user](../images/python-user/image.yaml) for all three settings.

### `entrypoint`

No module dependencies. Installs `/entrypoint.sh` and `/run-system-hooks.sh`.

| Directory | Identity | When |
|---|---|---|
| `/entrypoint.d` | root | Before user hooks |
| `/entrypoint.user.d` | container user | Before the requested command |

Executable files run in filename order; directories and non-executable files
are skipped. A failing hook stops startup and prevents the final command from
running. `VERBOSE_BOOT=yes` logs hook names. The final command replaces the
entrypoint process with `exec`.

Non-root system hooks require sudo. The installed sudoers rule permits only
`/run-system-hooks.sh` with no arguments. It is independent of `USER_SUDO=yes`.
User hooks do not need sudo. See the [startup-hooks example](../images/startup-hooks).

`entrypoint` does not install sudo. Install that RPM in the consuming module
when non-root execution needs system hooks. `USER_SUDO=yes` installs it too,
but grants broader privileges than the restricted system-hook rule. No sudo is
needed when there are no executable system hooks. Keep system hooks and their
runner root-owned and unwritable by the runtime user.

The runner does not change the container's selected user: with a root container,
user hooks also run as root. Hooks run as separate processes, so their exports
do not alter the final command's environment. They must tolerate repeated starts.
With no command the runner exits after hooks. Overriding the image entrypoint
bypasses the runner unless the replacement delegates to it.

## Git and package tools

| Module | Installs | Module dependencies |
|---|---|---|
| `git` | `git-core` and a user update hook | `entrypoint` |
| `make` | GNU Make | none |
| `jq` | jq | none |
| `yq` | Mike Farah's yq | `epel` |
| `ripgrep` | ripgrep, command `rg` | `epel` |
| `helm` | Helm, tar and gzip | `epel` |
| `epel` | EPEL repository RPM | none |

Git does not clone a project at image build time. Its optional hook runs
`git -C "$GIT_UPDATE_DIR" pull --ff-only` at startup when `GIT_UPDATE_DIR` is
set. `GIT_UPDATE=no` disables it. The directory must already contain a checkout
with an upstream branch, writable by the user. Credentials are supplied separately.

`EPEL_MAJOR_VERSION=auto` detects the major version using the RPM RHEL macro;
explicit values are 8, 9 or 10. Installing EPEL does not make every package
available on every UBI version.

## Python and Ansible

### `python`

Depends on `entrypoint`. `PYTHONMAJORVERSION` is a build argument: `3` by default,
or a supported package family such as `3.12`. Availability depends on UBI.
Installs the matching pip package, which brings its Python runtime.

pip uses its standard index and configuration. `PIP_INDEX_URL` is pip's own
runtime environment setting, not a custom CEKit module argument. Additional
packages installed during a build must receive their configuration at that
build step, through a consumer's recipe or mounted configuration.

The module sets `REQUESTS_CA_BUNDLE` to the system CA bundle and defines
`PIP_INSTALL_OPTIONS` for consuming scripts. It does not install a custom CA.

The optional `50-python-pypirc.sh` user hook writes `$HOME/.pypirc` when all
three runtime variables are provided:

- `PYPI_UPLOAD_URL`: full upload endpoint.
- `PYPI_USER`: upload username.
- `PYPI_PASSWORD`: upload password/token.

The upload entry is named `custom`. The file is replaced atomically with mode
0600. Without an upload URL, nothing is written. This is upload configuration;
it does not change the pip download index.

### `ansible`

Depends on `python`. Installs `ansible-core` and OpenSSH clients. Project-specific
Python dependencies are not bundled. The default language is `C.UTF-8` and
module working directory is `/root`; the consuming image can override it.

| Runtime variable | Effect |
|---|---|
| `ANSIBLE_PROJECT_DIR` | Directory used for optional project operations |
| `ANSIBLE_UPDATE=yes` | Run Galaxy role/collection updates in that directory |
| `ANSIBLE_INVENTORY` | Inventory chosen by the caller, using normal Ansible semantics |
| `ANSIBLE_PRIVATE_KEY_FILE` | Explicit SSH key; otherwise the project wrapper derives the user key path |

Select `/ansible-entrypoint.sh` when using the project wrapper. It delegates to
`/credentials-entrypoint.sh` if installed, otherwise `/entrypoint.sh`. Galaxy
updates read `roles/requirements.yml` and `collections/requirements.yml` when
present; no files are required for a plain Ansible image.

## Trust and credentials

### `ca`

No module dependencies. Installs `ca-certificates`, copies a caller-supplied
certificate to the system anchor directory and updates system trust.

Override the artifact named `custom-ca`, including its target name:

```yaml
artifacts:
  - name: custom-ca
    path: private/custom-ca.crt
    target: custom-ca.crt
```

No certificate is bundled. Generation fails without the input or an override.
The certificate is included in the resulting image, so image distribution must
match its intended audience. A private CA does not belong in this public repo.
See [the custom CA recipe](recipes.md#install-a-custom-ca).

### `vault`

No module dependencies. Requires build argument `VAULT_VERSION` with a release
number such as the one in [the credentials example](../images/credentials/image.yaml).
Downloads the Linux amd64 ZIP and installs the CLI. It installs unzip when
needed, removing it afterward only if it was not already installed.
It does not configure an address, token or server.

### `credentials`

Depends on `entrypoint` and `vault`; installs OpenSSH clients and Bash for the
SSH hook. It does not require a custom user. `HOME` must exist and be writable.

Use `/credentials-entrypoint.sh` to prepare the Vault session before hooks, or
`/ansible-entrypoint.sh` for an Ansible image using the same integration.
Configure `VAULT_ADDR`. Supply a valid `VAULT_TOKEN`, an existing token-helper
session, or AppRole credentials. The container does not inherit the host token
helper automatically: explicitly pass a token or mount the required files.

AppRole accepts `VAULT_APPROLE_ROLE_ID` and `VAULT_APPROLE_SECRET_ID`, with
`/vault/secrets/role_id` and `/vault/secrets/secret_id` as file fallbacks.
The wrapper authenticates when a netrc/file Vault lookup needs a session.

| Hook | Activation and options |
|---|---|
| `55-credentials-netrc.sh` | `NETRC_VAULT_PATH`, `NETRC_VAULT_MOUNT`, `NETRC_HOST`, `NETRC_USER`; `NETRC_VAULT_FIELD=token` by default |
| `60-credentials-secret-file.sh` | `CREDENTIAL_FILE`, plus a source described below |
| `70-ssh-vault-ca.sh` | `VAULT_SSH_CA_ENABLED=yes`, `VAULT_ADDR`, `VAULT_SSH_ROLE`, `VAULT_SSH_PRINCIPAL` |

The netrc hook manages one entry, replacing `$HOME/.netrc` atomically with
mode 0600 on each configured startup.

The generic file hook preserves an existing destination. Otherwise source
precedence is an existing `CREDENTIAL_SOURCE_FILE`, a nonempty
`CREDENTIAL_VALUE`, then `CREDENTIAL_VAULT_PATH` with required
`CREDENTIAL_VAULT_MOUNT`. `CREDENTIAL_VAULT_FIELD` defaults to `password`.
It creates a mode-0600 file; the parent directory must exist.

SSH defaults: key `${USER_HOME:-$HOME}/.ssh/id_ed25519`, TTL `8h`, renewal margin
`3600` seconds. `VAULT_SSH_KEY`, `VAULT_SSH_TTL` and `VAULT_SSH_RENEW` override
them. Signing uses `ssh/sign/<role>`. The hook can use an existing session,
AppRole, or interactive OIDC fallback. Prefer a token/AppRole for container runs;
a browser callback to localhost inside a container is not the host callback.
The key path must also be passed to any application that uses it; hook exports
do not propagate back into the final command's environment.

## Java and developer tools

`java` installs a headless OpenJDK runtime. `jdk` depends on `java` and adds the
matching `-devel` RPM. Both use build argument `JAVA_MAJOR_VERSION=21` by default.

| Base | Supported Java major versions |
|---|---|
| UBI 9 | 8, 11, 17, 21, 25 |
| UBI 10 | 21, 25 |

The runtime module sets `JAVA_HOME=/usr/lib/jvm/jre`; the JDK module sets
`JAVA_HOME=/usr/lib/jvm/java`. Unsupported combinations are rejected before
package installation. Java 6 and private binary distributions are not included.

| Module | Build argument | Default | Installation |
|---|---|---|---|
| `oc` | `OC_VERSION` | `4.21.17` | Official Linux amd64 archive and Bash completion |
| `kubeconform` | `KUBECONFORM_VERSION` | `v0.6.7` | Official Linux amd64 archive |
| `kube-linter` | `KUBE_LINTER_VERSION` | `v0.7.2` | Official Linux amd64 archive |

The two validators install tar/gzip themselves and do not depend on Helm.
Kubeconform normally fetches schemas at validation time; use a local schema
location for offline validation. No validator installs kubeadm or kubectl.
Release download scripts check HTTP failures and clean temporary files. They
currently do not verify a separate upstream archive checksum.

## HTTP and container tools

`apache` installs `httpd`, `mod_proxy_html` and a foreground launcher, retaining
the distribution configuration. It declares port 80 and `/etc/httpd` as its
working directory. It does not depend on EPEL or `entrypoint`; add `entrypoint`
when the consuming image needs hooks. `httpd-foreground` loads
`/etc/httpd/envvars` if present and clears the old PID before starting.

`buildah`, `podman` and `skopeo` depend on `user` and `git`. They install nested
storage configuration with fuse-overlayfs and shared stores. Buildah and Podman
set `BUILDAH_ISOLATION=chroot`; Skopeo sets `REGISTRY_AUTH_FILE=/tmp/auth.json`.
The account uses the `user` arguments. UID/GID must be below 65535 for these
modules' subordinate ranges.

Storage configuration alone does not grant host kernel permissions. Running
nested builds may need devices, namespace mappings and capabilities supplied
by the runtime. The example does not enable privileged mode. Volumes and the
final runtime user are choices for the consuming image.
