#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

refresh() {
  sketchybar --set calendar.title label="$(date '+%A · %-d %B %Y')" \
             --set calendar.weekdays label=" Su  Mo  Tu  We  Th  Fr  Sa "

  year="$(date '+%Y')"
  month="$(date '+%m')"
  today="$(date '+%-d')"
  first_weekday="$(date -j -f '%Y-%m-%d' "$year-$month-01" '+%w')"
  days_in_month="$(cal "$month" "$year" | awk 'NF { last=$NF } END { print last }')"
  nbsp="$(printf '\302\240')"

  row=1
  while [ "$row" -le 6 ]; do
    line=""
    has_date=false
    column=0
    while [ "$column" -lt 7 ]; do
      day=$(( (row - 1) * 7 + column - first_weekday + 1 ))
      if [ "$day" -ge 1 ] && [ "$day" -le "$days_in_month" ]; then
        has_date=true
        if [ "$day" -eq "$today" ]; then
          field="$(printf '[%2d]' "$day")"
        else
          field="$(printf ' %2d ' "$day")"
        fi
      else
        field="    "
      fi
      line="$line$field"
      column=$((column + 1))
    done

    if [ "$has_date" = true ]; then
      line="$(printf '%s' "$line" | sed "s/ /$nbsp/g")"
      sketchybar --set "calendar.week.$row" drawing=on label="$line"
    else
      sketchybar --set "calendar.week.$row" drawing=off
    fi
    row=$((row + 1))
  done
}

case "$1" in
  toggle)
    sketchybar --set wifi popup.drawing=off \
               --set battery popup.drawing=off \
               --set volume popup.drawing=off \
               --set music popup.drawing=off
    if [ "$(sketchybar --query clock | jq -r '.popup.drawing')" = "on" ]; then
      sketchybar --set clock popup.drawing=off
      "$CONFIG_DIR/plugins/popup_dismiss.sh" stop clock
    else
      refresh
      sketchybar --set clock popup.drawing=on
      "$CONFIG_DIR/plugins/popup_dismiss.sh" start clock >/dev/null 2>&1 &
    fi
    ;;
  open)
    sketchybar --set clock popup.drawing=off
    "$CONFIG_DIR/plugins/popup_dismiss.sh" stop clock
    open -a Calendar
    ;;
esac
