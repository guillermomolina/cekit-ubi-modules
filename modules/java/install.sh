#!/bin/sh
set -eu
version=${JAVA_MAJOR_VERSION:-21}
ubi=$(rpm --eval '%{rhel}')
case "$ubi:$version" in
    9:8|9:11|9:17|9:21|9:25|10:21|10:25) ;;
    *) echo "Unsupported combination: UBI $ubi / Java $version. Use UBI 9 for Java 8/11/17, or UBI 9/10 for Java 21/25." >&2; exit 1 ;;
esac
if [ "$version" = 8 ]; then
    package=java-1.8.0-openjdk
else
    package=java-$version-openjdk
fi
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y "$package-headless"
microdnf clean all
test -x /usr/lib/jvm/jre/bin/java
/usr/lib/jvm/jre/bin/java -version
