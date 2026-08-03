#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

case "$1" in
  toggle)
    sketchybar --set wifi popup.drawing=off \
               --set battery popup.drawing=off \
               --set clock popup.drawing=off \
               --set volume popup.drawing=off
    if [ "$(sketchybar --query music | jq -r '.popup.drawing')" = "on" ]; then
      sketchybar --set music popup.drawing=off
      "$CONFIG_DIR/plugins/popup_dismiss.sh" stop music
    else
      sketchybar --set music popup.drawing=on
      "$CONFIG_DIR/plugins/popup_dismiss.sh" start music >/dev/null 2>&1 &
    fi
    ;;
esac
