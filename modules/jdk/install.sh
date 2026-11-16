#!/bin/sh
set -eu
# The java dependency validates JAVA_MAJOR_VERSION against the UBI version.
version=${JAVA_MAJOR_VERSION:-21}
if [ "$version" = 8 ]; then
    package=java-1.8.0-openjdk
else
    package=java-$version-openjdk
fi
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y "$package-devel"
microdnf clean all
test -x /usr/lib/jvm/java/bin/javac
/usr/lib/jvm/java/bin/javac -version
