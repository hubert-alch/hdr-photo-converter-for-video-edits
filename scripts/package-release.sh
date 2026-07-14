#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/release"
APP_NAME="HDR Photo Converter for Video Editors"
BUNDLE_ID="com.forlovegame.hdr-photo-converter"
VERSION="${VERSION:-0.1.0}"
DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-15.0}"
ARCH="${ARCH:-$(uname -m)}"
TEAM_ID="${TEAM_ID:-WP5P2JDX6U}"
DEFAULT_SIGNING_IDENTITY="Developer ID Application: FORLOVE GAME LIMITED ($TEAM_ID)"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
NOTARIZE="${NOTARIZE:-0}"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
APP_EXECUTABLE="$MACOS_DIR/$APP_NAME"
WORKER_EXECUTABLE="$MACOS_DIR/$APP_NAME Converter"
ZIP_PATH="$BUILD_DIR/$APP_NAME-$VERSION-macOS.zip"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION-macOS.dmg"
NOTARY_API_KEY_PATH=""

APP_SOURCES=(
    "$ROOT_DIR/Sources/App/UltraHDRToFCPApp.swift"
    "$ROOT_DIR/Sources/Models/AppModels.swift"
    "$ROOT_DIR/Sources/Services/AppleGainMapComposer.swift"
    "$ROOT_DIR/Sources/Services/BatchConversionService.swift"
    "$ROOT_DIR/Sources/Services/FCPXMLWriter.swift"
    "$ROOT_DIR/Sources/Services/HDRPhotoInspector.swift"
    "$ROOT_DIR/Sources/Services/HLGComposer.swift"
    "$ROOT_DIR/Sources/Services/ImageDecoder.swift"
    "$ROOT_DIR/Sources/Services/JPEGGainMapReader.swift"
    "$ROOT_DIR/Sources/Services/ProResExporter.swift"
    "$ROOT_DIR/Sources/Stores/ConversionStore.swift"
    "$ROOT_DIR/Sources/Views/ContentView.swift"
    "$ROOT_DIR/Sources/Views/DetailView.swift"
    "$ROOT_DIR/Sources/Views/SourceQueueView.swift"
)

WORKER_SOURCES=(
    "$ROOT_DIR/Sources/Worker/ConversionWorkerMain.swift"
    "$ROOT_DIR/Sources/Models/AppModels.swift"
    "$ROOT_DIR/Sources/Services/AppleGainMapComposer.swift"
    "$ROOT_DIR/Sources/Services/HDRPhotoInspector.swift"
    "$ROOT_DIR/Sources/Services/HLGComposer.swift"
    "$ROOT_DIR/Sources/Services/ImageDecoder.swift"
    "$ROOT_DIR/Sources/Services/JPEGGainMapReader.swift"
    "$ROOT_DIR/Sources/Services/ProResExporter.swift"
)

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

export MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"

swiftc -O -parse-as-library -target "$ARCH-apple-macos$DEPLOYMENT_TARGET" "${APP_SOURCES[@]}" -o "$APP_EXECUTABLE"
swiftc -O -parse-as-library -target "$ARCH-apple-macos$DEPLOYMENT_TARGET" "${WORKER_SOURCES[@]}" -o "$WORKER_EXECUTABLE"

cp "$ROOT_DIR/Assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>$DEPLOYMENT_TARGET</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS_DIR/Info.plist"

if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' -v identity="$DEFAULT_SIGNING_IDENTITY" 'index($0, identity) { print $2; exit }')"
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
    echo "Signing with $SIGNING_IDENTITY"
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$WORKER_EXECUTABLE"
    codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
else
    echo "Developer ID identity not found; using ad-hoc signing."
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH"

if [[ -n "$SIGNING_IDENTITY" ]]; then
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
    codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ "$NOTARIZE" == "1" ]]; then
    notary_args=()
    if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
        notary_args+=(--keychain-profile "$NOTARYTOOL_PROFILE")
    elif [[ -n "${APPLE_API_KEY_BASE64:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" ]]; then
        NOTARY_API_KEY_PATH="$BUILD_DIR/AuthKey_$APPLE_API_KEY_ID.p8"
        echo "$APPLE_API_KEY_BASE64" | base64 --decode > "$NOTARY_API_KEY_PATH"
        notary_args+=(--key "$NOTARY_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID")
    elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
        notary_args+=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$TEAM_ID")
    else
        echo "NOTARIZE=1 requires NOTARYTOOL_PROFILE, App Store Connect API key secrets, or Apple ID app-specific password secrets." >&2
        exit 1
    fi
    xcrun notarytool submit "$DMG_PATH" --wait "${notary_args[@]}"
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
fi

echo "$ZIP_PATH"
echo "$DMG_PATH"
