#!/bin/bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$ROOT_DIR/common"
IOS_DIR="$ROOT_DIR/ios"
MACOS_DIR="$ROOT_DIR/macos"
IOS_SPM_DIR="$IOS_DIR/device_calendar/Sources/device_calendar"
MACOS_SPM_DIR="$MACOS_DIR/device_calendar/Sources/device_calendar"

mkdir -p "$IOS_SPM_DIR" "$MACOS_SPM_DIR"

for file in "$COMMON_DIR"/*; do
  filename="$(basename "$file")"
  ln -sf "../common/$filename" "$IOS_DIR/$filename"
  ln -sf "../common/$filename" "$MACOS_DIR/$filename"
  cp "$file" "$IOS_SPM_DIR/"
  cp "$file" "$MACOS_SPM_DIR/"
done

echo "Symlinks and Swift Package Manager sources updated for iOS and macOS."
