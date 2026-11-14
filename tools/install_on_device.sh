#!/usr/bin/env bash
# Install the three signed release APKs on the connected Android device.
#
# Usage:  tools/install_on_device.sh [app ...]
#         (no arguments = customer, vendor, rider)
#
# The APKs come from the latest successful GitHub Actions run, so they are
# exactly the ones that were published.
set -euo pipefail

REPO="tejaskhanna989/anterkart-builds-repohouse"
WORKFLOW="build-apks.yml"
DEST="${DEST:-/tmp/opencode/install-apks}"

APPS=("$@")
if [ ${#APPS[@]} -eq 0 ]; then
  APPS=(customer vendor rider)
fi

if ! command -v adb > /dev/null 2>&1; then
  echo "adb not found in PATH" >&2
  exit 1
fi

echo "=== Devices ==="
adb start-server > /dev/null 2>&1 || true
adb devices -l
if ! adb devices | awk 'NR>1 && $2=="device"' | grep -q .; then
  echo "No device connected. Plug the phone in, enable USB debugging and" >&2
  echo "accept the RSA prompt on the phone." >&2
  exit 1
fi

echo
echo "=== Latest successful CI run ==="
RUN=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --status success --limit 1 \
      --json databaseId --jq '.[0].databaseId')
if [ -z "$RUN" ]; then
  echo "No successful CI run found" >&2
  exit 1
fi
echo "run $RUN"

rm -rf "$DEST"
mkdir -p "$DEST"

for app in "${APPS[@]}"; do
  echo
  echo "=== $app ==="
  gh run download "$RUN" --repo "$REPO" -n "$app-apk" -D "$DEST/$app"
  apk=$(find "$DEST/$app" -name 'app-arm64-v8a-release.apk' | head -1)
  if [ -z "$apk" ]; then
    apk=$(find "$DEST/$app" -name '*-release.apk' | head -1)
  fi
  if [ -z "$apk" ]; then
    echo "No APK found for $app" >&2
    exit 1
  fi
  echo "  $(basename "$apk") ($(du -h "$apk" | cut -f1))"

  # The phone must accept the upgrade: the signature has to match the one
  # that is already installed, otherwise the install fails.
  adb install -r "$apk" || {
    echo "  retrying after uninstall (signature changed)" >&2
    case "$app" in
      customer) pkg=com.otamzo.store ;;
      vendor)   pkg=com.otamzo.vendor ;;
      rider)    pkg=com.otamzo.rider ;;
    esac
    adb uninstall "$pkg" || true
    adb install "$apk"
  }
done

echo
echo "=== Installed packages ==="
adb shell pm list packages | grep otamzo || true
echo
echo "Done. Open the apps and sign in."
