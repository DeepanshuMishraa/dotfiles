#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

refresh() {
  battery="$(pmset -g batt)"
  percentage="$(printf '%s\n' "$battery" | grep -Eo '[0-9]+%' | head -1)"
  source="$(printf '%s\n' "$battery" | sed -n "s/^Now drawing from '\(.*\)'/\1/p")"

  case "$battery" in
    *'; charging;'*) state="Charging" ;;
    *'; charged;'*) state="Fully Charged" ;;
    *'; discharging;'*) state="On Battery" ;;
    *) state="Unknown" ;;
  esac

  health_info="$(system_profiler SPPowerDataType -json 2>/dev/null \
    | jq -r '.SPPowerDataType[0].sppower_battery_health_info // {}')"
  health="$(printf '%s\n' "$health_info" | jq -r '.sppower_battery_health // "Unknown"')"
  capacity="$(printf '%s\n' "$health_info" | jq -r '.sppower_battery_health_maximum_capacity // "Unknown"')"
  cycles="$(printf '%s\n' "$health_info" | jq -r '.sppower_battery_cycle_count // "Unknown"')"

  [ -n "$percentage" ] || percentage="Unknown"
  [ -n "$source" ] || source="Unknown"
  sketchybar --set battery.charge label="Charge · $percentage ($state)" \
             --set battery.source label="Source · $source" \
             --set battery.health label="Health · $health ($capacity)" \
             --set battery.cycles label="Cycles · $cycles"
}

case "$1" in
  toggle)
    sketchybar --set wifi popup.drawing=off \
               --set clock popup.drawing=off \
               --set volume popup.drawing=off \
               --set music popup.drawing=off
    if [ "$(sketchybar --query battery | jq -r '.popup.drawing')" = "on" ]; then
      sketchybar --set battery popup.drawing=off
      "$CONFIG_DIR/plugins/popup_dismiss.sh" stop battery
    else
      refresh
      sketchybar --set battery popup.drawing=on
      "$CONFIG_DIR/plugins/popup_dismiss.sh" start battery >/dev/null 2>&1 &
    fi
    ;;
  settings)
    sketchybar --set battery popup.drawing=off
    "$CONFIG_DIR/plugins/popup_dismiss.sh" stop battery
    open 'x-apple.systempreferences:com.apple.Battery-Settings.extension'
    ;;
esac
