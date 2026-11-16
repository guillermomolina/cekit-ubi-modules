#!/bin/sh
set -eu
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y helm tar gzip
microdnf clean all
