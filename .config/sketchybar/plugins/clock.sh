#!/bin/sh

# The $NAME variable is passed from sketchybar and holds the name of
# the item invoking this script:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

if [ "$SENDER" = "mouse.exited.global" ]; then
  sketchybar --set "$NAME" popup.drawing=off
  "$CONFIG_DIR/plugins/popup_dismiss.sh" stop "$NAME"
  exit 0
fi

sketchybar --set "$NAME" label="$(date '+%a %-e %b %H:%M')"
