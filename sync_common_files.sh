#!/bin/bash

# Directories
COMMON_DIR="../common"
IOS_DIR="./ios"
MACOS_DIR="./macos"

# Create symlinks for iOS
cd "$IOS_DIR"
for file in $(ls -A $COMMON_DIR); do
  ln -sf "$COMMON_DIR/$file" .
done

# Create symlinks for macOS
cd "../$MACOS_DIR"
for file in $(ls -A $COMMON_DIR); do
  ln -sf "$COMMON_DIR/$file" .
done

echo "Symlinks updated for iOS and macOS."
