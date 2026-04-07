#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Project Launcher"
PRODUCT_NAME="ProjectLauncher"
BUILD_DIR="$PWD/.build/release"
APP_DIR="$PWD/dist/$APP_NAME.app"
EXECUTABLE="$BUILD_DIR/$PRODUCT_NAME"
ICON_DIR="$PWD/build/Icon.iconset"
ICON_PNG="$PWD/build/AppIcon-1024.png"
ICON_ICNS="$PWD/build/AppIcon.icns"

mkdir -p "$PWD/build"

swift build -c release

rm -rf "$ICON_DIR"
mkdir -p "$ICON_DIR"

swift "$PWD/scripts/generate_icon.swift" "$ICON_PNG"

sips -z 16 16 "$ICON_PNG" --out "$ICON_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_PNG" --out "$ICON_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_PNG" --out "$ICON_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_PNG" --out "$ICON_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_PNG" --out "$ICON_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICON_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICON_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICON_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICON_DIR/icon_512x512.png" >/dev/null
cp "$ICON_PNG" "$ICON_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICON_DIR" -o "$ICON_ICNS"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>ProjectLauncher</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>io.github.chaceraiter.project-launcher</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Project Launcher</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleSignature</key>
  <string>PLCH</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Project Launcher needs automation access to open iTerm or Terminal windows for your selected projects.</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

printf 'APPLPLCH' > "$APP_DIR/Contents/PkgInfo"

cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/ProjectLauncher"
cp "$ICON_ICNS" "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "Built app bundle at: $APP_DIR"
