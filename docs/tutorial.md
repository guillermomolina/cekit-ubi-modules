# Tutorial: from UBI to a reusable image

This tutorial uses the checked-in examples. It does not require a cluster,
private repository, custom certificate or Vault account.

Commands start at the repository root. Buildah and Podman must already work on
your host; the examples use them directly rather than mounting a host daemon.

## 1. Prepare the tools

Install Python 3.12 or newer, Git, Make, Buildah and Podman using your host's
package manager. Then prepare CEKit in a virtual environment:

```sh
git clone https://github.com/guillermomolina/cekit-ubi-modules.git
cd cekit-ubi-modules
python3 -m venv .venv
. .venv/bin/activate
python -m pip install 'cekit==4.16.0'
cekit --version
buildah --version
podman --version
```

Activate `.venv` again in a new terminal. It places the `cekit` command on PATH.
The virtual environment and generated files are ignored by Git.

## 2. Generate before building

```sh
make -C images/minimal generate
cat images/minimal/target/image/Containerfile
```

The descriptor is `images/minimal/image.yaml`. It selects UBI 10 minimal and
installs `entrypoint`, which provides the startup hook runners. The generated
Containerfile shows exactly what CEKit will build. Edit the descriptor or module
sources, not `target/`: the next generation replaces generated output.

`generate` does not install packages or create a container image. It still needs
to resolve module repositories and any file artifacts. The checked-in examples
use the local `modules/` directory, so they do not clone another module repo.

## 3. Build and execute the image

```sh
make -C images/minimal build
podman run --rm --network=none localhost/examples/minimal:latest \
  /bin/sh -c 'printf "%s\n" ready'
```

The command should print `ready`. Runtime arguments replace the example's
`run.cmd`, while the entrypoint runs first and then executes your command.

The tag is independent of module versions. For another tag, use the same value
when building and running:

```sh
make -C images/minimal build IMAGE=localhost/examples/minimal:dev
make -C images/minimal run IMAGE=localhost/examples/minimal:dev
```

Builds need access to the UBI registry and any package/download repositories
used by the selected modules. `--network=none` above applies only to execution.

## 4. Select tools and let dependencies resolve

```sh
make -C images/chart generate
```

Read `images/chart/image.yaml`. Its install list contains `git`, `helm`,
`kubeconform` and `kube-linter`. It does not need to repeat `entrypoint` or
`epel`: `git` depends on the former and `helm` on the latter. CEKit expands
those dependencies and installs shared modules once.

There are three different version choices:

| Setting | What it controls |
|---|---|
| Image `name` and `version`, or the Makefile's `IMAGE` | Output image reference |
| A module's own `version` | Version of its installation recipe |
| An argument such as `KUBECONFORM_VERSION` | Upstream binary release installed by the recipe |

Changing the output image tag does not select a different tool version. Change
the appropriate argument in the image descriptor instead.

## 5. Run Python without root

### Building an account versus running as that account

Modules compose the image at build time; hooks compose its startup at runtime.
These are separate stages:

| Stage | What happens | Who runs it |
|---|---|---|
| Build | `user` creates the account and home; other modules install packages and hooks | root by default; a module can select `execute.user` for an installation script |
| Container start | `/entrypoint.d/*` prepares system configuration | root |
| Container start | `/entrypoint.user.d/*` prepares user configuration | the container's selected user |
| Application | The entrypoint executes the requested command | the same selected user |

Declaring a module dependency controls build order. Hook filenames control
startup order. A module that installs a hook must depend on `entrypoint` so the
hook directory and runner exist before its installer runs. A script that needs
a particular account during installation must also declare a dependency on
`user` and select its `execute.user` explicitly.

The `user` and `entrypoint` modules can be used independently. A root container
can use hooks without creating an account, and an image can create an account
without using startup hooks.

```sh
make -C images/python-user build
podman run --rm --network=none localhost/examples/python-user:latest
```

Expected output:

```text
uid=1000 home=/home/app
```

The example declares `user` and `python`. Account creation happens during the
build as root. `run.user` selects UID 1000 only for the finished container;
`HOME` and `run.workdir` point at that account's writable directory. Installing
`user` alone does not switch the final runtime user.

The relevant descriptor settings are:

```yaml
args:
  - name: USER_NAME
    value: app
  - name: USER_UID
    value: "1000"
  - name: USER_GID
    value: "1000"
envs:
  - name: HOME
    value: /home/app
run:
  user: "1000"
  workdir: /home/app
```

`USER_HOME` defaults to `/home/<USER_NAME>` during account creation. It does not
set runtime `HOME`: keep those paths consistent in the consuming image. Changing
`USER_UID` also requires updating `run.user`. Files needed by the application
must be readable or writable by that UID; creating the account does not change
ownership of files installed by other modules or bind-mounted from the host.

Inspect the account from inside the same image:

```sh
podman run --rm --network=none localhost/examples/python-user:latest \
  /bin/sh -c 'id; printf "HOME=%s\n" "$HOME"; pwd'
```

## 6. Add a local startup hook

```sh
make -C images/startup-hooks build
podman run --rm --network=none localhost/examples/startup-hooks:latest
```

Expected output, in order:

```text
startup hook: ready
command: ready
```

The example's local module is in `images/startup-hooks/modules/hello`:

1. `module.yaml` declares the hook artifact and depends on `entrypoint`.
2. `install.sh` copies it into `/entrypoint.user.d` with executable permissions.
3. `files/hello.sh` runs as the container user at every start.

The image declares two uniquely named module repositories: the shared catalog
and its local project modules. The image's install list only needs
`example_hello`. This is also how a separate private repository can add policy
or configuration without modifying the public recipes.

Hooks run as separate processes: exporting a variable in a hook does not change
the environment of the final command. Declare runtime variables in the image or
supply them with `podman --env`. An unsuccessful hook stops startup.

### Combining system hooks and a non-root user

For example, an image could install these executable files during the build:

```text
/entrypoint.d/20-system-config.sh
/entrypoint.user.d/50-user-config.sh
/entrypoint.user.d/90-project-update.sh
```

With `run.user: "1000"`, every normal container start follows this sequence:

```text
/entrypoint.sh (UID 1000)
  -> sudo -n /run-system-hooks.sh
       -> 20-system-config.sh (root)
  -> 50-user-config.sh (UID 1000)
  -> 90-project-update.sh (UID 1000)
  -> exec requested-command (UID 1000)
```

Each directory is processed separately in filename order: all system hooks
finish before any user hook, regardless of their numeric prefixes. Use system
hooks for files that require root, and user hooks for files under `HOME` or a
user-owned project. Hooks run on every start, so make repeated execution safe.

**Non-root execution with system hooks requires sudo to be installed.**
`entrypoint` writes a rule allowing only `/run-system-hooks.sh` without arguments,
but does not install sudo. A consuming module can install the `sudo` RPM during
the build to use that restricted rule. `USER_SUDO=yes` also installs sudo, but
additionally grants the account unrestricted passwordless sudo; it is not
required merely to use system hooks. Keep the system runner, its hooks and
their directories owned by root and unwritable by the application user.

If there are no executable system hooks, a non-root container needs no sudo.
When the container runs as root, both types of hooks run as root: the entrypoint
does not switch to the account created by `user`.

The entrypoint stops at the first failed hook and returns its status. With no
command, it finishes after the hooks; it does not start a shell automatically.
Use `VERBOSE_BOOT=yes` to see hook names. Passing `--entrypoint` to Podman
replaces the startup runner and bypasses these hooks. A custom wrapper should
delegate with `exec /entrypoint.sh "$@"` after its own preparation so the shared
hooks and final command still run.

## 7. Consume the modules from your own repository

Use a Git repository entry in your own `image.yaml`:

```yaml
schema_version: 1
name: localhost/my-python
version: latest
from: docker.io/redhat/ubi10-minimal:latest
modules:
  repositories:
    - name: public-modules
      git:
        url: https://github.com/guillermomolina/cekit-ubi-modules.git
        ref: main
  install:
    - name: python
run:
  cmd: [python3, --version]
```

From the directory containing that descriptor:

```sh
cekit build --dry-run buildah
cekit build buildah --tag localhost/my-python:latest --no-squash
podman run --rm --network=none localhost/my-python:latest
```

`main` is convenient for discovery. For a repeatable build, replace it with an
actual reviewed commit or published tag. Pinning the module repository does not
pin mutable UBI tags or the RPM versions available at build time.

## 8. Check and clean up

```sh
make check
make -C images/minimal clean
make -C images/python-user clean
make -C images/startup-hooks clean
```

`make check` checks shared shell scripts and generates each example. It does
not build images, run the sample commands or scan for private data. The custom
CA example is skipped until you supply its own certificate.

Continue with the [recipes](recipes.md), [module reference](module-reference.md)
or [example catalog](../images/README.md).
