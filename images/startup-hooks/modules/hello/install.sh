#!/bin/sh
set -eu
install -m 0755 /tmp/artifacts/example-hello.sh /entrypoint.user.d/90-example-hello.sh
