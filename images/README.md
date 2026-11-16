# Example images

All examples start directly from UBI minimal and consume `../../modules` from
this checkout. They do not require building another example first.

From the repository root, after activating the CEKit environment:

```sh
make -C images/python generate
make -C images/python build
podman run --rm --network=none localhost/examples/python:latest python3 --version
```

Each directory has the same four targets: `generate`, `build`, `run`, `clean`.
`IMAGE` changes the output tag; use the same override with `run` and `clean`.
The Makefiles intentionally do not contain publishing or credential automation.

| Example | What it demonstrates | Try after building |
|---|---|---|
| [minimal](minimal/image.yaml) | Basic entrypoint on UBI | `podman run --rm localhost/examples/minimal:latest /bin/sh -c 'echo ready'` |
| [python](python/image.yaml) | Python and pip with public defaults | `podman run --rm localhost/examples/python:latest python3 --version` |
| [python-user](python-user/image.yaml) | Account creation, HOME and non-root execution | `podman run --rm localhost/examples/python-user:latest` |
| [startup-hooks](startup-hooks/image.yaml) | A local module adding a hook, with a declared dependency | `podman run --rm localhost/examples/startup-hooks:latest` |
| [ansible](ansible/image.yaml) | Public Ansible and its optional project wrapper | `podman run --rm localhost/examples/ansible:latest ansible --version` |
| [apache](apache/image.yaml) | Foreground HTTP Server using distribution configuration | See the [HTTP recipe](../docs/recipes.md#run-apache-and-make-an-http-request) |
| [chart](chart/image.yaml) | Git, Helm, kubeconform and kube-linter | `podman run --rm localhost/examples/chart:latest helm version --short` |
| [jdk](jdk/image.yaml) | JDK 21 with a transitive Java runtime dependency | `podman run --rm localhost/examples/jdk:latest javac -version` |
| [container-tools](container-tools/image.yaml) | Buildah/Skopeo storage and a shared account | `podman run --rm localhost/examples/container-tools:latest buildah --version` |
| [credentials](credentials/image.yaml) | Optional credential hooks and Vault CLI | See [runtime secret files](../docs/recipes.md#write-a-generic-secret-file-without-vault) |
| [custom-ca](custom-ca/image.yaml) | Certificate artifact supplied by the caller | Provide `private/custom-ca.crt` first; see the [CA recipe](../docs/recipes.md#install-a-custom-ca) |

## What is deliberately not automatic

- Custom CA input is not bundled. `make check` skips that example without it.
- Vault hooks do nothing unless configured. No service credentials are supplied.
- Git updates do not clone a repository; they operate on an existing checkout.
- Apache's example Makefile does not publish a port; use the runtime command in
  the HTTP recipe.
- Container-tool installation does not grant the host permissions needed for
  nested containers. The example does not run privileged.
- kubeconform may need network access for schemas; choose a local schema path
  when validating offline.

Use [the tutorial](../docs/tutorial.md) for a guided walkthrough. The
[module reference](../docs/module-reference.md) lists arguments and defaults;
[recipes](../docs/recipes.md) show complete commands for common tasks.
