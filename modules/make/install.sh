#!/bin/sh
set -eu
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y make
microdnf clean all
