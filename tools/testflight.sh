#!/usr/bin/env bash
# Build Gnarcast on THIS Mac and upload it to TestFlight — the first path. The GitHub workflow
# (.github/workflows/testflight.yml) is the same build on a rented Mac, for when this one is away.
#
# Signs from a dedicated keychain (gnarcast-build) holding the app's distribution identity and the
# account's development identity, unlocked here with its own password, so nothing prompts. Profiles
# are fetched or made with the App Store Connect API key, not an Xcode account login.
#
# The build number is the time (YYYYMMDD.HHMM): TestFlight needs it higher than the last upload, and a
# clock is monotonic across this Mac and the workflow, which uses the same format.
set -euo pipefail
cd "$(dirname "$0")/.."
K="$HOME/.appstoreconnect/private_keys"
KC="$HOME/Library/Keychains/gnarcast-build.keychain-db"
KEY_ID=P8Y337A8RC
ISSUER=141a8ead-b829-4e58-b9ff-b8c95f8c4ed9
TEAM=XMH4AVFC78
BUILD="$(date -u +%Y%m%d.%H%M)"
OUT="$(mktemp -d)"

security unlock-keychain -p "$(cat "$K/gnarcast-build-keychain.password")" "$KC"
# On the keychain search list only while this runs: left there permanently, every ordinary build and
# codesign on the Mac finds its identities, hits it locked, and asks for a password nobody knows.
SEARCH_LIST=$(security list-keychains -d user | xargs -n1 | grep -v gnarcast-build | xargs)
trap 'security list-keychains -d user -s $SEARCH_LIST' EXIT
security list-keychains -d user -s "$KC" $SEARCH_LIST
xcodegen generate >/dev/null

AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$K/AuthKey_$KEY_ID.p8"
      -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER")

echo "archiving build $BUILD"
xcodebuild -project Gnarcast.xcodeproj -scheme Gnarcast -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/Gnarcast.xcarchive" \
  "${AUTH[@]}" DEVELOPMENT_TEAM="$TEAM" CURRENT_PROJECT_VERSION="$BUILD" \
  archive 2>&1 | grep -E "error:|warning: .*sign|ARCHIVE" || true
[ -d "$OUT/Gnarcast.xcarchive" ] || { echo "archive failed"; exit 1; }

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM</string>
  <key>uploadSymbols</key><true/>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$OUT/Gnarcast.xcarchive" -exportPath "$OUT/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" "${AUTH[@]}" 2>&1 | grep -E "error:|EXPORT" || true
IPA="$(ls "$OUT"/export/*.ipa 2>/dev/null | head -1)"
[ -n "$IPA" ] || { echo "export failed"; exit 1; }

echo "uploading $IPA"
xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$KEY_ID" --apiIssuer "$ISSUER" 2>&1 | tail -4
rm -rf "$OUT"
