#!/bin/bash
# Deploys the build artifact app/DO to the production VM over SSH.
# Required environment (GitLab CI/CD variables): DEPLOY_HOST, DEPLOY_USER.
# The runner's SSH key must be in DEPLOY_USER's authorized_keys on the host,
# and DEPLOY_USER needs passwordless sudo for /usr/bin/install only (see README).
set -euo pipefail

: "${DEPLOY_HOST:?DEPLOY_HOST is not set}"
: "${DEPLOY_USER:?DEPLOY_USER is not set}"

SOURCE_FILE="app/DO"
DEST="/usr/local/bin/DO"
REMOTE_TMP="/tmp/DO.$$"

echo "Deploying ${SOURCE_FILE} to ${DEPLOY_USER}@${DEPLOY_HOST}:${DEST}..."

scp -o BatchMode=yes "${SOURCE_FILE}" "${DEPLOY_USER}@${DEPLOY_HOST}:${REMOTE_TMP}"

# install sets owner root:root and mode 755 in one step; the previous mv + chmod +x
# kept the artifact's 777 mode, so any local user could overwrite a binary in PATH
ssh -o BatchMode=yes "${DEPLOY_USER}@${DEPLOY_HOST}" \
  "sudo /usr/bin/install -o root -g root -m 755 ${REMOTE_TMP} ${DEST} && rm -f ${REMOTE_TMP} && ls -l ${DEST}"

echo "Deploy finished successfully!"
