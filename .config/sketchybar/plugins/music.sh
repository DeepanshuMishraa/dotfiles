#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

update() {
  RUNNING="$(osascript -e 'application "Music" is running')"
  if [ "$RUNNING" = "false" ]; then
    sketchybar --set music drawing=off popup.drawing=off
    exit 0
  fi

  STATE="$(osascript -e 'tell application "Music" to player state')"
  TRACK="$(osascript -e 'tell application "Music" to name of current track')"
  ARTIST="$(osascript -e 'tell application "Music" to artist of current track')"
  SHUFFLE="$(osascript -e 'tell application "Music" to shuffle enabled')"
  REPEAT="$(osascript -e 'tell application "Music" to song repeat')"

  sketchybar --set music drawing=on \
             --set music.track label="${TRACK}  ${ARTIST}"

  if [ "$STATE" = "playing" ]; then
    sketchybar --set music.play icon=󰏤
  else
    sketchybar --set music.play icon=󰐊
  fi

  sketchybar --set music.shuffle icon.highlight="$SHUFFLE"
  if [ "$REPEAT" = "off" ]; then
    sketchybar --set music.repeat icon.highlight=off
  else
    sketchybar --set music.repeat icon.highlight=on
  fi
}

next() { osascript -e 'tell application "Music" to play next track'; }
back() { osascript -e 'tell application "Music" to play previous track'; }
play() { osascript -e 'tell application "Music" to playpause'; }

repeat() {
  REPEAT="$(osascript -e 'tell application "Music" to get song repeat')"
  if [ "$REPEAT" = "off" ]; then
    osascript -e 'tell application "Music" to set song repeat to all'
  else
    osascript -e 'tell application "Music" to set song repeat to off'
  fi
  update
}

shuffle() {
  SHUFFLE="$(osascript -e 'tell application "Music" to get shuffle enabled')"
  if [ "$SHUFFLE" = "false" ]; then
    osascript -e 'tell application "Music" to set shuffle enabled to true'
  else
    osascript -e 'tell application "Music" to set shuffle enabled to false'
  fi
  update
}

if [ "$SENDER" = "mouse.exited.global" ]; then
  sketchybar --set music popup.drawing=off
  "$CONFIG_DIR/plugins/popup_dismiss.sh" stop music
elif [ "$SENDER" = "mouse.clicked" ]; then
  case "$NAME" in
    music.next) next ;;
    music.back) back ;;
    music.play) play ;;
    music.shuffle) shuffle ;;
    music.repeat) repeat ;;
  esac
  sleep 0.1
  sketchybar --set music popup.drawing=on
  "$CONFIG_DIR/plugins/popup_dismiss.sh" start music >/dev/null 2>&1 &
else
  update
fi
