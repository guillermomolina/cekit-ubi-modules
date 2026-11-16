#!/bin/sh
set -eu
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y httpd mod_proxy_html
microdnf clean all
install -m 0755 /tmp/artifacts/httpd-foreground /usr/local/bin/httpd-foreground
mkdir -p /run/httpd
httpd -t
