#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/release"
APP_NAME="HDR Photo Converter for Video Editors"
BUNDLE_ID="com.forlovegame.hdr-photo-converter"
VERSION="${VERSION:-0.1.0}"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
APP_EXECUTABLE="$MACOS_DIR/$APP_NAME"
WORKER_EXECUTABLE="$MACOS_DIR/$APP_NAME Converter"
ZIP_PATH="$BUILD_DIR/$APP_NAME-$VERSION-macOS.zip"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION-macOS.dmg"

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

swiftc -O -parse-as-library "${APP_SOURCES[@]}" -o "$APP_EXECUTABLE"
swiftc -O -parse-as-library "${WORKER_SOURCES[@]}" -o "$WORKER_EXECUTABLE"

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
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH"

echo "$ZIP_PATH"
echo "$DMG_PATH"
