#!/usr/bin/env bash
# Upload the release signing material of the three apps to the GitHub
# repository as Actions secrets, so CI can produce properly signed APKs.
set -euo pipefail

REPO="tejaskhanna989/anterkart-builds-repohouse"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set_secret() {
  local name="$1" value="$2"
  printf '%s' "$value" | gh secret set "$name" --repo "$REPO" --body "$(printf '%s' "$value")" 2>/dev/null \
    || printf '%s' "$value" | gh secret set "$name" --repo "$REPO"
  echo "  set $name"
}

for app in customer vendor rider; do
  upper=$(echo "$app" | tr '[:lower:]' '[:upper:]')
  ks="$ROOT/$app/android/app/upload-keystore.jks"
  props="$ROOT/$app/android/key.properties"

  if [ ! -f "$ks" ]; then
    echo "ERROR: missing keystore $ks"; exit 1
  fi

  store_pw=$(grep '^storePassword=' "$props" | cut -d= -f2-)
  key_pw=$(grep '^keyPassword=' "$props" | cut -d= -f2-)
  alias=$(grep '^keyAlias=' "$props" | cut -d= -f2-)
  b64=$(base64 -w0 "$ks")

  echo "=== $app (alias=$alias) ==="
  set_secret "KEYSTORE_BASE64_$upper" "$b64"
  set_secret "KEYSTORE_PASSWORD_$upper" "$store_pw"
  set_secret "KEY_PASSWORD_$upper" "$key_pw"
  set_secret "KEY_ALIAS_$upper" "$alias"
done

echo
echo "=== Secrets now present ==="
gh secret list --repo "$REPO"
