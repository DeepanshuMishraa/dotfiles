#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
SOURCE="$CONFIG_DIR/helpers/WiFiSSID.swift"
PLIST="$CONFIG_DIR/helpers/WiFiSSID-Info.plist"
BUNDLE="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar/WiFiSSID.app"
BINARY="$BUNDLE/Contents/MacOS/WiFiSSID"

if [ ! -x "$BINARY" ] || [ "$SOURCE" -nt "$BINARY" ] || [ "$PLIST" -nt "$BINARY" ]; then
  mkdir -p "$BUNDLE/Contents/MacOS"
  cp "$PLIST" "$BUNDLE/Contents/Info.plist"
  xcrun swiftc "$SOURCE" \
    -framework AppKit \
    -framework CoreLocation \
    -framework CoreWLAN \
    -o "$BINARY" || exit 0
  codesign --force --sign - --identifier com.deepanshu.sketchybar.wifissid "$BUNDLE" >/dev/null 2>&1 || exit 0
fi

"$BINARY" 2>/dev/null
