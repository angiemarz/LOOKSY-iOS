#!/usr/bin/env bash
# Validates the device build and packages two IPAs:
#   LOOKSY-unsigned.ipa  -> Payload/LOOKSY.app without any signature
#   LOOKSY-adhoc.ipa     -> same app with an ad-hoc (pseudo) signature
# AltStore re-signs either one on the iPhone with the user's free Apple ID.
# Usage: package-ipa.sh <path/to/LOOKSY.app> <output dir>
set -euo pipefail
APP="$1"
OUT="$2"
fail() { echo "::error::$1"; exit 1; }

[ -d "$APP" ] || fail "App bundle not found at $APP"
EXEC_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$APP/Info.plist")
BINARY="$APP/$EXEC_NAME"
[ -f "$BINARY" ] || fail "Executable $EXEC_NAME missing inside the app"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Info.plist")
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$APP/Info.plist")
PLATFORMS=$(/usr/libexec/PlistBuddy -c "Print :CFBundleSupportedPlatforms" "$APP/Info.plist" | tr -d '\n ')

echo "Bundle ID:      $BUNDLE_ID"
echo "Version:        $VERSION ($BUILD)"
echo "Minimum iOS:    $MIN_OS"
echo "Platforms:      $PLATFORMS"
echo "$PLATFORMS" | grep -q "iPhoneOS" || fail "CFBundleSupportedPlatforms is not iPhoneOS (simulator build?)"
echo "$PLATFORMS" | grep -q "iPhoneSimulator" && fail "App was built for the simulator"

ARCHS=$(lipo -archs "$BINARY")
echo "Architectures:  $ARCHS"
echo "$ARCHS" | grep -q "arm64" || fail "Binary is not arm64"
echo "$ARCHS" | grep -q "x86_64" && fail "Binary contains simulator architecture x86_64"

# LC_BUILD_VERSION platform 2 = iOS device, 7 = iOS simulator.
PLATFORM_ID=$(otool -l "$BINARY" | awk '/LC_BUILD_VERSION/{f=1} f && /platform/{print $2; exit}')
echo "Mach-O platform: $PLATFORM_ID"
[ "$PLATFORM_ID" = "2" ] || [ "$PLATFORM_ID" = "IOS" ] || fail "Mach-O platform is '$PLATFORM_ID', expected 2 (iOS device)"

[ -f "$APP/Assets.car" ] || echo "::warning::Assets.car not found (app icon may be missing)"

rm -rf "$OUT"
mkdir -p "$OUT/unsigned/Payload" "$OUT/adhoc/Payload"

# 1) Unsigned IPA
cp -R "$APP" "$OUT/unsigned/Payload/"
rm -rf "$OUT/unsigned/Payload/LOOKSY.app/_CodeSignature"
(cd "$OUT/unsigned" && zip -qry "../LOOKSY-unsigned.ipa" Payload)

# 2) Ad-hoc signed IPA (no certificate, no Apple account involved)
cp -R "$APP" "$OUT/adhoc/Payload/"
codesign --force --sign - --timestamp=none "$OUT/adhoc/Payload/LOOKSY.app"
codesign --verify --verbose=2 "$OUT/adhoc/Payload/LOOKSY.app"
(cd "$OUT/adhoc" && zip -qry "../LOOKSY-adhoc.ipa" Payload)

for IPA in "$OUT/LOOKSY-unsigned.ipa" "$OUT/LOOKSY-adhoc.ipa"; do
  echo "Checking $IPA"
  unzip -l "$IPA" | grep -q "Payload/LOOKSY.app/$EXEC_NAME$" || fail "$IPA has no Payload/LOOKSY.app/$EXEC_NAME"
  unzip -l "$IPA" | grep -q "Payload/LOOKSY.app/Info.plist$" || fail "$IPA has no Info.plist"
  FIRST=$(unzip -Z1 "$IPA" | head -n 1)
  case "$FIRST" in Payload/*) ;; *) fail "$IPA top-level entry is '$FIRST', expected Payload/" ;; esac
  ls -lh "$IPA"
done

{
  echo "LOOKSY $VERSION ($BUILD)"
  echo "Bundle ID: $BUNDLE_ID"
  echo "Minimum iOS: $MIN_OS"
  echo "Architectures: $ARCHS"
  echo "Commit: ${GITHUB_SHA:-local}"
  echo "Built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Xcode: $(xcodebuild -version | head -n 1)"
  echo ""
  echo "LOOKSY-adhoc.ipa    -> recommended for AltStore (ad-hoc signature, AltStore re-signs it)"
  echo "LOOKSY-unsigned.ipa -> alternative without any signature"
  echo "Neither file is installable by itself: AltStore must sign it with your Apple ID."
} > "$OUT/BUILD_INFO.txt"
cat "$OUT/BUILD_INFO.txt"
