#!/bin/zsh
# Builds ZyManager.app into ./build
#   ./build-app.sh            native architecture, for local use
#   ./build-app.sh --release  universal (Apple Silicon + Intel) app, plus a zip and its SHA-256 for GitHub releases
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
# Ad-hoc signature: there is no Developer ID certificate yet, so the app isn't notarized.
codesign --force --sign - "$APP" >/dev/null

echo "Hazır: $PWD/$APP ($(lipo -archs "$APP/Contents/MacOS/ZyManager"))"

if (( RELEASE )); then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
    ZIP="build/ZyManager-$VERSION.zip"
    rm -f "$ZIP"
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
    (cd build && shasum -a 256 "${ZIP:t}" > "${ZIP:t}.sha256")
    echo "Zip: $PWD/$ZIP"
    cat "$ZIP.sha256"
fi
