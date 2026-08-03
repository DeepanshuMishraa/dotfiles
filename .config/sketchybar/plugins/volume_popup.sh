#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

refresh() {
  volume="$(osascript -e 'output volume of (get volume settings)')"
  muted="$(osascript -e 'output muted of (get volume settings)')"
  output="$(SwitchAudioSource -c -t output 2>/dev/null)"

  [ -n "$output" ] || output="Unknown"
  if [ "$muted" = "true" ]; then
    mute_label="Unmute"
  else
    mute_label="Mute"
  fi

  sketchybar --set volume.slider slider.percentage="$volume" \
             --set volume.output label="Output · $output" \
             --set volume.mute label="$mute_label"
}

case "${1:-$SENDER}" in
  toggle)
    sketchybar --set wifi popup.drawing=off \
               --set battery popup.drawing=off \
               --set clock popup.drawing=off \
               --set music popup.drawing=off
    if [ "$(sketchybar --query volume | jq -r '.popup.drawing')" = "on" ]; then
      sketchybar --set volume popup.drawing=off
      "$CONFIG_DIR/plugins/popup_dismiss.sh" stop volume
    else
      refresh
      sketchybar --set volume popup.drawing=on
      "$CONFIG_DIR/plugins/popup_dismiss.sh" start volume >/dev/null 2>&1 &
    fi
    ;;
  mouse.clicked)
    osascript -e "set volume output volume $PERCENTAGE"
    sketchybar --trigger volume_change INFO="$PERCENTAGE"
    sleep 0.1
    sketchybar --set volume popup.drawing=on
    "$CONFIG_DIR/plugins/popup_dismiss.sh" start volume >/dev/null 2>&1 &
    ;;
  volume_change)
    if [ -n "$INFO" ]; then
      sketchybar --set volume.slider slider.percentage="$INFO"
    else
      refresh
    fi
    ;;
  output)
    SwitchAudioSource -n -t output >/dev/null
    refresh
    sleep 0.1
    sketchybar --set volume popup.drawing=on
    "$CONFIG_DIR/plugins/popup_dismiss.sh" start volume >/dev/null 2>&1 &
    ;;
  mute)
    SwitchAudioSource -m toggle -t output >/dev/null
    refresh
    NAME=volume SENDER=forced "$CONFIG_DIR/plugins/volume.sh"
    sleep 0.1
    sketchybar --set volume popup.drawing=on
    "$CONFIG_DIR/plugins/popup_dismiss.sh" start volume >/dev/null 2>&1 &
    ;;
  settings)
    sketchybar --set volume popup.drawing=off
    "$CONFIG_DIR/plugins/popup_dismiss.sh" stop volume
    open 'x-apple.systempreferences:com.apple.Sound-Settings.extension'
    ;;
esac
