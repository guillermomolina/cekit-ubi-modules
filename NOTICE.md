# Third-party notices

cekit-ubi-modules
Copyright 2026 guillermomolina

This repository is provided under the Apache License, Version 2.0 (LICENSE).
Installed tools and packages retain their own licenses; their binaries are not
included in this repository.

The nested-storage recipes and configuration in modules/buildah,
modules/podman and modules/skopeo are modified adaptations of the public
image_build container recipes:

https://github.com/podman-container-tools/image_build

Those adapted files retain Apache-2.0 licensing; see LICENSE. Changes include CEKit module integration, dependency
handling, explicit storage configuration and configurable user accounts.
