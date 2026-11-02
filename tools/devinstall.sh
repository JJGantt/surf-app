#!/usr/bin/env bash
# Build Gnarcast on this Mac and install it straight onto the phone, no TestFlight. Use when the
# upload cap is hit or the change is not worth a TestFlight build.
#
# THE BUILD NUMBER IS THE POINT. project.yml carries CURRENT_PROJECT_VERSION "1", and a watch app
# claiming build 1 is a DOWNGRADE from whatever TestFlight last put on the watch — watchOS then
# refuses it silently, the Watch app's spinner completes and the app never appears. So this stamps the
# same UTC timestamp testflight.sh does, which is monotonic across both paths.
#
# Requires, once per device: the watch registered in the developer account (the phone registers
# itself through the build below), Developer Mode on in Settings > Privacy & Security, and the matching iOS device support files, which
# Xcode offers to download on first connect.
set -euo pipefail
cd "$(dirname "$0")/.."
K="$HOME/.appstoreconnect/private_keys"
KEY_ID=P8Y337A8RC
ISSUER=141a8ead-b829-4e58-b9ff-b8c95f8c4ed9
TEAM=XMH4AVFC78
BUILD="$(date -u +%Y%m%d.%H%M)"

# The phone: devicectl's identifier for the install, and its hardware UDID for xcodebuild, which
# registers that UDID in the developer account if it is not there yet. A device devicectl lists as
# `unavailable` is an old pairing, not the phone on the desk.
read -r DEV UDID < <(xcrun devicectl list devices --json-output /dev/stdout 2>/dev/null | python3 -c '
import json, sys
want = sys.argv[1] if len(sys.argv) > 1 else ""
text = sys.stdin.read()
devs = json.loads(text[text.index("{"):])["result"]["devices"]
for d in devs:
    hw, cp = d["hardwareProperties"], d["connectionProperties"]
    if want and want not in (d["identifier"], hw.get("udid")): continue
    if not want and (hw.get("deviceType") != "iPhone" or cp.get("tunnelState") == "unavailable"): continue
    print(d["identifier"], hw.get("udid")); break
' "${1:-}")
[ -n "${UDID:-}" ] || { echo "no connected iPhone; pass its devicectl identifier as \$1"; exit 1; }

xcodegen generate >/dev/null

echo "building $BUILD"
xcodebuild -project Gnarcast.xcodeproj -scheme Gnarcast -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build/dev \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration -authenticationKeyPath "$K/AuthKey_$KEY_ID.p8" \
  -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER" \
  DEVELOPMENT_TEAM="$TEAM" CURRENT_PROJECT_VERSION="$BUILD" build 2>&1 \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" || true

APP=build/dev/Build/Products/Debug-iphoneos/Gnarcast.app
[ -d "$APP" ] || { echo "build failed"; exit 1; }
xcrun devicectl device install app --device "$DEV" "$APP" 2>&1 | grep -E "App installed|bundleID|ERROR" || true
echo "watch app: iPhone > Watch > Gnarcast > Show App on Apple Watch, off then on"
