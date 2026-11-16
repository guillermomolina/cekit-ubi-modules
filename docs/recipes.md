# Practical recipes

[README](../README.md) · [Tutorial](tutorial.md) · [Module reference](module-reference.md)

Run these commands from the repository root with the CEKit virtual environment
activated. Secret-prompt examples use Bash. Addresses ending in `example.invalid`
are placeholders: replace them with services you control.

## Install a custom CA

Bring your own public CA certificate in PEM format, without a private key:

```sh
mkdir -p images/custom-ca/private
cp /path/to/your-ca.crt images/custom-ca/private/custom-ca.crt
make -C images/custom-ca generate
make -C images/custom-ca build
```

For a disposable local test, generate a test CA instead (requires OpenSSL):

```sh
mkdir -p images/custom-ca/private
openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -subj '/CN=Example Test CA' \
  -keyout images/custom-ca/private/test-ca.key \
  -out images/custom-ca/private/custom-ca.crt
```

Then build as above. The key stays outside the build artifact; only
`custom-ca.crt` is selected by the descriptor. Both files are ignored by Git.
The CA is installed at `/etc/pki/ca-trust/source/anchors/custom-ca.crt` and
included in the image's trust store. It is not a runtime secret.

In a different image, list `ca` before any module that needs the resulting
trust store for an HTTPS download. For a private CA, publish the resulting
image only where that CA is intended to be visible.

## Run Apache and make an HTTP request

```sh
make -C images/apache build
podman run --rm -d --name ubi-apache \
  -p 127.0.0.1:8080:80 --stop-signal SIGWINCH \
  localhost/examples/apache:latest
podman exec ubi-apache /bin/sh -c \
  'printf "%s\n" hello > /var/www/html/example.txt'
curl --fail http://127.0.0.1:8080/example.txt
podman logs ubi-apache
podman stop ubi-apache
```

The HTTP response should contain `hello`. Using a specific file avoids the
distribution's welcome-page behavior. `--rm` removes the container after stop;
changes made with `podman exec` are disposable. For real content or virtual
hosts, supply artifacts or mounts from the consuming image. The module does
not include an organization's proxy networks, headers or virtual hosts.

## Package a Helm chart

```sh
make -C images/chart build
podman run --rm --network=none localhost/examples/chart:latest \
  /bin/sh -ec 'cd /tmp; helm create demo; helm lint demo; helm template demo demo > rendered.yaml; helm package demo; tar -tzf demo-0.1.0.tgz'
```

This works locally without a Kubernetes cluster. Artifacts in `/tmp` disappear
with the container. To keep outputs, use a writable bind mount and choose the
runtime user/ownership appropriate for your host.

Inspect the installed validators:

```sh
podman run --rm --network=none localhost/examples/chart:latest kubeconform -v
podman run --rm --network=none localhost/examples/chart:latest kube-linter version
```

For an existing chart, mount it read-only. The chart's dependencies must already
be available or be fetched separately:

```sh
podman run --rm --volume "$PWD/my-chart:/work/chart:ro" \
  localhost/examples/chart:latest helm lint /work/chart
```

`helm template` renders manifests. Pipe that output into kubeconform or
kube-linter for validation. Kubeconform normally downloads Kubernetes schemas;
`--network=none` requires a separately supplied local schema directory. A
successful version command is not a manifest-validation test.

## Use Java 8 on UBI 9

Generate or build the JDK example with two overrides together:

```sh
(cd images/jdk && cekit build \
  --overrides '{"from":"docker.io/redhat/ubi9-minimal:latest","args":[{"name":"JAVA_MAJOR_VERSION","value":"8"}]}' \
  buildah --tag localhost/examples/jdk8:latest --no-squash)
podman run --rm --network=none localhost/examples/jdk8:latest javac -version
```

Changing only the argument to Java 8 while retaining UBI 10 will fail. Java
11/17 also need UBI 9; 21/25 work on UBI 9 or 10. The default example is JDK 21
on UBI 10. For an application needing only a JRE, choose module `java` rather
than `jdk` in its descriptor.

Compile a small program with the default example:

```sh
make -C images/jdk build
podman run --rm --network=none localhost/examples/jdk:latest /bin/sh -ec \
  'cd /tmp; printf "%s\n" "public class Hello { public static void main(String[] args) { System.out.println(\"hello\"); } }" > Hello.java; javac Hello.java; java Hello'
```

## Run Ansible locally

```sh
make -C images/ansible build
podman run --rm --network=none \
  --env ANSIBLE_CACHE_PLUGIN=memory \
  localhost/examples/ansible:latest \
  ansible localhost -i localhost, -c local -m ansible.builtin.ping
```

This checks local execution without an inventory server or remote host. It is
independent of your host's Ansible installation.

To work with a project:

```sh
podman run --rm -it --volume "$PWD/my-ansible-project:/workspace:ro" \
  --env ANSIBLE_PROJECT_DIR=/workspace \
  --env ANSIBLE_INVENTORY=/workspace/inventory.ini \
  --env ANSIBLE_UPDATE=no \
  localhost/examples/ansible:latest ansible-inventory --list
```

Set `ANSIBLE_UPDATE=yes` only when you want startup Galaxy updates and provide
a writable location for roles/collections. Private repositories need credentials
supplied separately. The public module does not guess an environment name or
inventory path and does not install a project's Python integration packages.

## Write a generic secret file without Vault

Build the credentials example once, then pass a value only at runtime:

```sh
make -C images/credentials build
read -r -s -p 'Secret value: ' CREDENTIAL_VALUE
printf '\n'
export CREDENTIAL_VALUE
podman run --rm --network=none \
  --env CREDENTIAL_FILE=/tmp/example-secret --env CREDENTIAL_VALUE \
  localhost/examples/credentials:latest \
  /bin/sh -c 'test -s /tmp/example-secret && stat -c %a /tmp/example-secret'
unset CREDENTIAL_VALUE
```

The output should be `600`; it does not print the secret. No Vault request is
made because no Vault source is configured. A mounted source file can be used
instead through `CREDENTIAL_SOURCE_FILE`. An existing destination is preserved.

The example runs as root. For a non-root image, create a writable home with
`user`, set `HOME` and `run.user`, and select a writable destination. The
`credentials` module itself does not require the `user` module.

## Generate netrc from your Vault deployment

The following requires a real Vault service, a KV mount, a secret containing
field `token`, and permission to read it. Example names are placeholders.

```sh
export VAULT_ADDR=https://vault.example.invalid
read -r -s -p 'Vault token: ' VAULT_TOKEN
printf '\n'
export VAULT_TOKEN
podman run --rm \
  --env VAULT_ADDR --env VAULT_TOKEN \
  --env NETRC_HOST=git.example.invalid \
  --env NETRC_USER=example-user \
  --env NETRC_VAULT_MOUNT=kv \
  --env NETRC_VAULT_PATH=services/git \
  localhost/examples/credentials:latest \
  /bin/sh -c 'test -s "$HOME/.netrc" && stat -c %a "$HOME/.netrc"'
unset VAULT_TOKEN
```

No secret is written into the image descriptor or build arguments. Do not use
`cat` to verify credentials in shared logs. Module defaults do not include any
real service addresses, mount names, roles or principals.

For SSH certificates, separately configure `VAULT_SSH_CA_ENABLED=yes`,
`VAULT_SSH_ROLE` and `VAULT_SSH_PRINCIPAL` for a role on the `ssh` secrets engine.
Pass the resulting key path to your application. See the
[credential reference](module-reference.md#credentials).

## Keep private policy outside the public catalog

A consuming image can read public recipes and private modules together:

```yaml
modules:
  repositories:
    - name: public-modules
      git:
        url: https://github.com/guillermomolina/cekit-ubi-modules.git
        ref: main
    - name: private-modules
      path: /path/to/your/private-modules
  install:
    - name: your_private_configuration
```

This fragment assumes that `your_private_configuration` exists in the private
repository. That module can depend on a public tool and apply your own policy.
Keep names distinct and keep its certificates, service addresses, secret paths
and private documentation in the private repository. The public catalog does
not need to know where or how it is consumed.

## Troubleshooting

| Symptom | Check |
|---|---|
| `cekit: command not found` | Activate `.venv`, or pass an absolute path with `CEKIT=/path/to/cekit` to Make |
| Generation succeeds, runtime fails | Generation does not execute installers or test the kernel/runtime |
| Missing `custom-ca.crt` | Supply the ignored private certificate and include `target: custom-ca.crt` in the override |
| Unknown module | Check repository paths, module `name`, and the selected Git ref |
| No matching RPM | Check UBI/Java compatibility and the enabled repositories; a module version is not an RPM version |
| Hook did not run | Check the selected entrypoint, executable permission and hook directory |
| Hook variable is missing from the application | Hooks are child processes; set variables in the image/runtime environment |
| Non-root file permission failure | Check `run.user`, `HOME`, bind-mount ownership and destination directory permissions |
| Unexpected network request | Git/Galaxy updates and Vault lookups are optional runtime features; unset their activation variables or disable updates |
| Nested Buildah/Podman permission failure | Check host devices/namespaces/capabilities and storage; module installation cannot grant these |

For debugging an image without invoking startup hooks:

```sh
podman run --rm -it --entrypoint /bin/sh localhost/examples/python:latest
```
