#!/bin/sh
set -eu
[ -z "${ANSIBLE_PROJECT_DIR:-}" ] && exit 0
[ "${ANSIBLE_UPDATE:-no}" != yes ] && exit 0
cd "$ANSIBLE_PROJECT_DIR"
if [ -f roles/requirements.yml ]; then
    ansible-galaxy role install -r roles/requirements.yml --keep-scm-meta --force
fi
if [ -f collections/requirements.yml ]; then
    ansible-galaxy collection install -r collections/requirements.yml --force
fi
