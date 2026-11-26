#!/usr/bin/env bash
# Publish the validated release APKs to the production download paths.
#
# The APKs are uploaded to a staging directory first, verified on the server
# against the SHA1 digests computed locally, and only then moved into the
# public download directory. A failed or partial upload can therefore never
# replace a working download.
set -euo pipefail

WEBROOT="${OTAMZO_WEBROOT:-/home/u881842192/domains/otamzo.com/public_html}"
SSH_HOST="${OTAMZO_SSH_HOST:-91.108.107.50}"
SSH_PORT="${OTAMZO_SSH_PORT:-65002}"
SSH_USER="${OTAMZO_SSH_USER:-u881842192}"
SSH_PASSWORD="${OTAMZO_SSH_PASSWORD:?OTAMZO_SSH_PASSWORD is required}"
STAGE="/tmp/otamzo-apk-release"

APPS="${OTAMZO_APPS:-customer vendor rider}"

ssh_opts=(-p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
export SSHPASS="$SSH_PASSWORD"

remote() {
  sshpass -e ssh "${ssh_opts[@]}" "$SSH_USER@$SSH_HOST" "$@"
}

for app in $APPS; do
  src="dist/$app"
  if [ ! -d "$src" ]; then
    echo "::error::No build output for $app at $src"
    exit 1
  fi

  echo "=== staging $app"
  remote "rm -rf '$STAGE/$app' && mkdir -p '$STAGE/$app'"

  files=$(cd "$src" && ls -1)
  for f in $files; do
    sshpass -e scp "${ssh_opts[@]}" "$src/$f" "$SSH_USER@$SSH_HOST:$STAGE/$app/$f"
  done

  # The server recomputes every digest and compares it with the one computed
  # in the build job. A mismatch means the upload was truncated or altered.
  echo "=== verifying $app on the server"
  remote "cd '$STAGE/$app' && sha1sum -c checksums.sha1" || {
    echo "::error::Checksum verification failed for $app on the server"
    exit 1
  }

  echo "=== publishing $app"
  remote "set -e
    target='$WEBROOT/download/$app'
    mkdir -p \"\$target\"
    for f in $files; do
      mv -f '$STAGE/$app/'\"\$f\" \"\$target/\$f\"
    done
    chmod 644 \"\$target\"/*
    cd \"\$target\"
    sha1sum -c checksums.sha1
    ls -l
  "

  remote "rm -rf '$STAGE/$app'"
done

echo "=== all apps published"
