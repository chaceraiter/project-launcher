#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Project Launcher.app"
SOURCE_APP="$PWD/dist/$APP_NAME"
TARGET_DIR="$HOME/Applications"
TARGET_APP="$TARGET_DIR/$APP_NAME"

./build-app.sh

mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_APP"
cp -R "$SOURCE_APP" "$TARGET_DIR/"
touch "$TARGET_APP" "$TARGET_APP/Contents" "$TARGET_APP/Contents/Info.plist"

printf 'Installed to %s\n' "$TARGET_APP"
printf 'Launch it with: open %q\n' "$TARGET_APP"
