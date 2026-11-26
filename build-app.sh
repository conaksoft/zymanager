#!/bin/zsh
# Builds ZyManager.app into ./build
#   ./build-app.sh            native architecture, for local use
#   ./build-app.sh --release  universal (Apple Silicon + Intel) app, Developer ID signed and notarized,
#                             plus a zip and its SHA-256 for GitHub releases
set -euo pipefail
cd "$(dirname "$0")"

RELEASE=0
[[ "${1:-}" == "--release" ]] && RELEASE=1

if (( RELEASE )); then
    ARGS=(-c release --arch arm64 --arch x86_64)
else
    ARGS=(-c release)
fi

swift build "${ARGS[@]}"
BIN="$(swift build "${ARGS[@]}" --show-bin-path)/ZyManager"
APP="build/ZyManager.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ZyManager"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Release builds are signed with the Developer ID certificate (hardened runtime, secure timestamp) and notarized;
# local builds get an ad-hoc signature. SIGN_ID overrides the identity.
SIGN_ID="${SIGN_ID:-Developer ID Application: CONAK SOFT LLC (LMY9XNPRWD)}"
if (( RELEASE )); then
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
    codesign --verify --strict --verbose=2 "$APP"
else
    codesign --force --sign - "$APP" >/dev/null
fi

echo "Hazır: $PWD/$APP ($(lipo -archs "$APP/Contents/MacOS/ZyManager"))"

if (( RELEASE )); then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
    ZIP="build/ZyManager-$VERSION.zip"
    rm -f "$ZIP"
    # Notarize, staple the ticket to the app, then zip the stapled app for distribution.
    # Credentials: xcrun notarytool store-credentials zymanager-notary (once per Mac). NOTARY_PROFILE overrides the name.
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "${NOTARY_PROFILE:-zymanager-notary}" --wait
    xcrun stapler staple "$APP"
    spctl --assess --type execute --verbose=2 "$APP"
    rm -f "$ZIP"
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
    (cd build && shasum -a 256 "${ZIP:t}" > "${ZIP:t}.sha256")
    echo "Zip: $PWD/$ZIP"
    cat "$ZIP.sha256"
fi
