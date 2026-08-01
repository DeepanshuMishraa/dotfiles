#!/bin/sh

WIFI="$(ipconfig getsummary en0 | awk -F ' SSID : ' '/ SSID : / {print $2}')"

if [ -n "$WIFI" ]; then
  ICON="󰖩"
  LABEL="$WIFI"
else
  ICON="󰖪"
  LABEL="Disconnected"
fi

sketchybar --set "$NAME" icon="$ICON" label="$LABEL"
