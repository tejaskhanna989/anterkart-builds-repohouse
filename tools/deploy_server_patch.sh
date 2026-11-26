#!/usr/bin/env bash
# Upload selected canonical server files to the live site.
#
# The PHP runs on Hostinger, so the only way in is the hPanel FTP account.
# Provide the credentials as environment variables:
#
#   FTP_HOST=ftp.otamzo.com FTP_USER=... FTP_PASS=... tools/deploy_server_patch.sh
#
# Optional:
#   FTP_PORT=21          (default 21)
#   REMOTE_ROOT=/public_html
#
# This script deliberately reads from the canonical project tree. Keep only one
# copy of each PHP file so a stale patch can never overwrite production code.
set -euo pipefail

FLUTTER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$FLUTTER_ROOT/.." && pwd)"

: "${FTP_HOST:?set FTP_HOST to the hPanel FTP host}"
: "${FTP_USER:?set FTP_USER to the hPanel FTP user}"
: "${FTP_PASS:?set FTP_PASS to the hPanel FTP password}"
FTP_PORT="${FTP_PORT:-21}"
REMOTE_ROOT="${REMOTE_ROOT:-/public_html}"

FILES=(
  "api/mobile/realtime/notify.php"
  "api/mobile/realtime/nearby_riders.php"
)

for relative in "${FILES[@]}"; do
  source_file="$PROJECT_ROOT/$relative"
  if [ ! -f "$source_file" ]; then
    echo "canonical source file not found: $source_file" >&2
    exit 1
  fi

done

echo "=== Uploading canonical server files ==="
echo "  host  : $FTP_HOST:$FTP_PORT"
echo "  root  : $REMOTE_ROOT"

for relative in "${FILES[@]}"; do
  source_file="$PROJECT_ROOT/$relative"
  curl --silent --show-error --fail \
    --user "$FTP_USER:$FTP_PASS" \
    --ftp-create-dirs \
    --upload-file "$source_file" \
    "ftp://$FTP_HOST:$FTP_PORT$REMOTE_ROOT/$relative"
  echo "  uploaded $relative"
done

echo
echo "=== Verifying ==="
curl --silent --show-error --fail \
  "https://otamzo.com/api/mobile/realtime/nearby_riders.php?store=all&lat=24.853545&lng=74.620191&radius_km=1"
echo
