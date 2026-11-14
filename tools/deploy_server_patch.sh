#!/usr/bin/env bash
# Upload the additive server patch to the live site.
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
# Nothing existing is overwritten: the patch only adds
# api/mobile/realtime/notify.php and api/mobile/realtime/nearby_riders.php.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_DIR="$ROOT/server-patch/api/mobile/realtime"

: "${FTP_HOST:?set FTP_HOST to the hPanel FTP host}"
: "${FTP_USER:?set FTP_USER to the hPanel FTP user}"
: "${FTP_PASS:?set FTP_PASS to the hPanel FTP password}"
FTP_PORT="${FTP_PORT:-21}"
REMOTE_ROOT="${REMOTE_ROOT:-/public_html}"

if [ ! -d "$PATCH_DIR" ]; then
  echo "patch directory not found: $PATCH_DIR" >&2
  exit 1
fi

echo "=== Uploading the server patch ==="
echo "  host  : $FTP_HOST:$FTP_PORT"
echo "  root  : $REMOTE_ROOT"
echo "  files : $PATCH_DIR"

curl --silent --show-error --fail \
  --user "$FTP_USER:$FTP_PASS" \
  --ftp-create-dirs \
  --upload-file "$PATCH_DIR/notify.php" \
  "ftp://$FTP_HOST:$FTP_PORT$REMOTE_ROOT/api/mobile/realtime/notify.php"

curl --silent --show-error --fail \
  --user "$FTP_USER:$FTP_PASS" \
  --ftp-create-dirs \
  --upload-file "$PATCH_DIR/nearby_riders.php" \
  "ftp://$FTP_HOST:$FTP_PORT$REMOTE_ROOT/api/mobile/realtime/nearby_riders.php"

echo "  uploaded notify.php"
echo "  uploaded nearby_riders.php"

echo
echo "=== Verifying ==="
curl -s "https://otamzo.com/api/mobile/realtime/nearby_riders.php?store=all&lat=24.853545&lng=74.620191&radius_km=1"
echo
echo
echo "=== Enabling the server side OneSignal push ==="
echo "Open admin/php/config.php on the server and set:"
echo "  define('ONESIGNAL_APP_ID', '99648958-99e9-4e1e-a015-96e4b512af7d');"
echo "  define('ONESIGNAL_REST_KEY', '<REST API KEY from OneSignal dashboard>');"
