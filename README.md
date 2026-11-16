# cekit-ubi-modules

Reusable CEKit modules for building modular container images on Red Hat UBI.

- `modules/`: reusable installation recipes and runtime hooks.
- `images/`: small, standalone image examples using the local modules.
- `tests/check.sh`: shell syntax checks and example generation.

The modules contain no organization-specific certificates, package servers,
Vault addresses or credentials. Private configuration belongs to the consuming
image or to a separate private module repository.

## Documentation

- [Step-by-step tutorial](docs/tutorial.md): build an image, add tools, run as
  a non-root user and add a startup hook.
- [Module reference](docs/module-reference.md): build arguments, runtime options,
  dependencies and entrypoints.
- [Practical recipes](docs/recipes.md): CA certificates, credentials, Ansible,
  Apache, charts and Java versions.
- [Runnable examples](images/README.md): choose an image and try its commands.

Start with the tutorial if you have not used CEKit before. All commands in the
guides assume the repository root unless another directory is shown.

The foundation is the [account and startup lifecycle](docs/tutorial.md#5-run-python-without-root):
modules install accounts, tools and hooks during the build; at startup the
entrypoint runs system hooks as root, user hooks as the selected container user,
then executes the application. Creating an account does not select the runtime
user. See the [combined hook example](docs/tutorial.md#combining-system-hooks-and-a-non-root-user)
for ordering, permissions and when sudo is required.

## Quick start

Requires Python 3.12+, CEKit 4.16.0, Git and Buildah. Podman runs the examples.

```sh
git clone https://github.com/guillermomolina/cekit-ubi-modules.git
cd cekit-ubi-modules
python3 -m venv .venv
. .venv/bin/activate
pip install 'cekit==4.16.0'
make check
make -C images/python generate
make -C images/python build
make -C images/python run
```

`generate` creates a Containerfile without building. `make check` checks shell
syntax and generates the example Containerfiles with CEKit. The `custom-ca`
example is skipped unless you supply its certificate. These checks do not
build images or run containers. Full builds require network access to package
repositories and upstream release servers.

## Modules

| Module | Purpose | Module dependencies |
|---|---|---|
| `ca` | Install a caller-supplied custom CA | none |
| `entrypoint` | System/user startup hooks and command execution | none |
| `user` | User, group, home and optional passwordless sudo | none |
| `sudo` | Sudo package; permissions configured by consuming modules | none |
| `epel` | Enable EPEL for the detected RHEL major version | none |
| `git` | Git Core and optional startup update | `entrypoint` |
| `make`, `jq` | GNU Make and JSON processing | none |
| `yq`, `ripgrep`, `helm` | YAML, text search, Helm/chart packaging | `epel` |
| `python` | Python/pip and optional package upload configuration | `entrypoint` |
| `ansible` | Ansible Core, OpenSSH client and optional project updates | `python` |
| `apache` | HTTP Server with distribution configuration | none |
| `java` | Headless OpenJDK runtime | none |
| `maven` | Apache Maven 3 with upstream settings | `jdk` |
| `jdk` | OpenJDK development tools | `java` |
| `vault` | Vault CLI | none |
| `credentials` | Optional runtime credential files and SSH certificates | `entrypoint`, `vault` |
| `buildah`, `podman`, `skopeo` | Container/image tooling with nested storage | `user`, `git` |
| `oc` | OpenShift CLI with Bash completion | none |
| `kubeconform`, `kube-linter` | Kubernetes manifest validation | none |

Dependencies are declared in `module.yaml`; CEKit resolves them transitively
and installs shared dependencies once. Modules declare package dependencies in
their installation scripts. Downloaded binaries are currently Linux amd64.
Tools installed from RPM follow the enabled repositories; upstream binary
versions are configured with their build arguments. Release downloads currently
use HTTPS without an additional archive checksum verification step.

## Use from another repository

```yaml
schema_version: 1
name: localhost/example
version: latest
from: docker.io/redhat/ubi10-minimal:latest
modules:
  repositories:
    - git:
        url: https://github.com/guillermomolina/cekit-ubi-modules.git
        ref: main
  install:
    - name: git
    - name: python
run:
  cmd: [/bin/sh]
```

Pin a reviewed commit or published release tag instead of `main` for repeatable
module selection. UBI tags and RPM updates also affect build reproducibility.
A second repository can supply private modules; use distinct module names and
keep all private configuration outside this public repository.

## Custom CA

No CA certificate is distributed. The `ca` module intentionally references a
missing input: the consuming image must override the artifact named `custom-ca`.
The certificate is a file artifact, not a secret value in a build argument.

```yaml
modules:
  repositories:
    - path: ../../modules
  install:
    - name: ca
artifacts:
  - name: custom-ca
    path: private/custom-ca.crt
    target: custom-ca.crt
```

The complete example is `images/custom-ca/image.yaml`. Put your own PEM
certificate at `images/custom-ca/private/custom-ca.crt` before building.
That directory and certificate files are ignored by Git. Do not add private
keys. The certificate becomes part of the resulting image's trust store, so
keep that image private if the certificate contains private infrastructure data.
Modules do not implicitly trust or depend on a private CA. List `ca` before
modules that must download from a server signed by it.

## Python and Ansible

`PYTHONMAJORVERSION` selects the RPM family (`3` by default). pip uses its normal
configuration and public package index by default; use pip's standard
`PIP_INDEX_URL` or a mounted configuration for an alternate index. Supply
credentials at runtime rather than placing them in image metadata.

The optional Python user hook writes `.pypirc` only when `PYPI_UPLOAD_URL`,
`PYPI_USER` and `PYPI_PASSWORD` are provided at runtime. The file is mode 0600.
The Ansible module installs `ansible-core`; additional project requirements
belong to the consuming image. `ANSIBLE_PROJECT_DIR` and `ANSIBLE_UPDATE=yes`
enable Galaxy role/collection updates. Set inventory explicitly with
`ANSIBLE_INVENTORY`. Use `/ansible-entrypoint.sh` when enabling these project
features, as shown in `images/ansible`.

## Credentials

All credential hooks are disabled unless configured and run as the container
user; a custom user module is optional. `HOME` must exist and be writable.
The module does not contain a Vault address or organization-specific defaults.
Use `/credentials-entrypoint.sh` as the image entrypoint to prepare a Vault
session before hooks (see `images/credentials`). Supply `VAULT_ADDR` and either
`VAULT_TOKEN` or AppRole credentials (`VAULT_APPROLE_ROLE_ID` and
`VAULT_APPROLE_SECRET_ID`, also accepted from `/vault/secrets/role_id` and
`/vault/secrets/secret_id`). No browser login is required inside the container.

| Output | Runtime settings |
|---|---|
| `$HOME/.netrc` | `NETRC_HOST`, `NETRC_USER`, `NETRC_VAULT_PATH`, `NETRC_VAULT_MOUNT`; field defaults to `token` (`NETRC_VAULT_FIELD`) |
| Generic secret file | `CREDENTIAL_FILE` and either `CREDENTIAL_SOURCE_FILE`, `CREDENTIAL_VALUE`, or `CREDENTIAL_VAULT_PATH` with `CREDENTIAL_VAULT_MOUNT`; field defaults to `password` (`CREDENTIAL_VAULT_FIELD`) |
| SSH certificate | `VAULT_SSH_CA_ENABLED=yes`, `VAULT_SSH_ROLE`, `VAULT_SSH_PRINCIPAL`; optional `VAULT_SSH_KEY` and `VAULT_SSH_TTL` |

`.netrc` manages one entry and is replaced atomically. Generic files preserve an
existing destination. Files have mode 0600. No values are logged. SSH uses the
`ssh/sign/<role>` backend; backend roles, principals and mounts must be supplied
for your deployment. SSH files are generated under the user's home by default.

## Other options and limitations

- `user`: `USER_NAME=user`, `USER_UID=1000`, `USER_GID=1000`, `USER_GROUP` defaults
  to the username, `USER_HOME` to `/home/<name>`, `USER_SHELL=/bin/bash`,
  `USER_SUDO=no`. Names and IDs must be free. `yes` grants passwordless sudo.
  The image selects the final `run.user`, `run.workdir` and runtime `HOME`.
- `git`: set `GIT_UPDATE_DIR` for `git pull --ff-only` at startup;
  `GIT_UPDATE=no` disables it. Provide credentials separately.
- `java`/`jdk`: `JAVA_MAJOR_VERSION=21`; UBI 9 supports 8/11/17/21/25,
  UBI 10 supports 21/25. Other combinations fail before package installation.
- `vault`: set build argument `VAULT_VERSION` explicitly.
- `oc`: `OC_VERSION=4.21.17`; `kubeconform`: `KUBECONFORM_VERSION=v0.6.7`;
  `kube-linter`: `KUBE_LINTER_VERSION=v0.7.2`.
- `apache`: distribution configuration and port 80. Override configuration in
  your image. CEKit 4.16 does not expose an image stop-signal field; use
  `podman run --stop-signal SIGWINCH` when graceful Apache shutdown is needed.
- Nested container tools require suitable host namespaces, capabilities and
  devices at runtime; creating a user and storage files does not grant those
  permissions. UID/GID must be below 65535 for the supplied subordinate ranges.
- `entrypoint` runs executable system hooks in `/entrypoint.d` as root and user
  hooks in `/entrypoint.user.d` as the current user. Non-root system hooks require
  the `sudo` module. Its sudo rule permits only `/run-system-hooks.sh`, without arguments;
  general passwordless sudo is a separate explicit `user` option.

## Contributing

Keep modules independent of private infrastructure. Use `example.com` or
`example.invalid` for documentation, never real credentials or certificates.
Run `make check` before committing. Keep build output, credentials and certificate
files out of Git. Before publishing, review the staged files for private
addresses, certificates and credentials; `make check` is not a privacy scan.

## License

Licensed under the Apache License, Version 2.0.
See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md) for attribution.
