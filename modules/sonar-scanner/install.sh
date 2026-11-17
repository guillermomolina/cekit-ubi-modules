#!/bin/sh
set -eu
version=${SONAR_SCANNER_VERSION:-6.2.1.4610}
case "$version" in
    ''|*[!0-9.]*) echo 'Set SONAR_SCANNER_VERSION to a numeric release.' >&2; exit 1 ;;
esac
case "${JAVA_MAJOR_VERSION:-21}" in
    17|21|25) ;;
    *) echo 'Use Java 17, 21 or 25 for SonarScanner.' >&2; exit 1 ;;
esac
microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y unzip findutils
microdnf clean all
work_dir=$(mktemp -d /tmp/sonar-scanner.XXXXXX)
trap 'rm -rf "$work_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
curl --fail --silent --show-error --location \
    "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-$version.zip" \
    -o "$work_dir/scanner.zip"
unzip -q "$work_dir/scanner.zip" -d "$work_dir"
mkdir -p /opt
mv "$work_dir/sonar-scanner-$version" /opt/sonar-scanner
chmod 0755 /opt/sonar-scanner/bin/sonar-scanner
ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/bin/sonar-scanner
JAVA_HOME=/usr/lib/jvm/jre sonar-scanner --version
