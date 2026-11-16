#!/bin/sh
set -eu
version=${MAVEN_VERSION:-3.9.14}
case "$version" in
    3.*) ;;
    *) echo 'This module supports Maven 3 releases.' >&2; exit 1 ;;
esac
case "$version" in
    *[!0-9.]*) echo 'Invalid MAVEN_VERSION.' >&2; exit 1 ;;
esac
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y tar gzip
microdnf clean all
work_dir=$(mktemp -d /tmp/maven.XXXXXX)
trap 'rm -rf "$work_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
url="https://archive.apache.org/dist/maven/maven-3/$version/binaries/apache-maven-$version-bin.tar.gz"
curl --fail --silent --show-error --location "$url" -o "$work_dir/maven.tar.gz"
curl --fail --silent --show-error --location "$url.sha512" -o "$work_dir/maven.sha512"
printf '%s  %s\n' "$(awk '{print $1}' "$work_dir/maven.sha512")" "$work_dir/maven.tar.gz" | sha512sum -c -
mkdir -p /usr/share/maven
tar -xzf "$work_dir/maven.tar.gz" -C /usr/share/maven --strip-components=1
ln -s /usr/share/maven/bin/mvn /usr/bin/mvn
mvn --version
