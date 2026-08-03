#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
SOURCE="$CONFIG_DIR/helpers/PopupDismiss.swift"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
BINARY="$CACHE_DIR/PopupDismiss"
ACTION="$1"
POPUP="$2"
PID_FILE="$CACHE_DIR/popup-dismiss-$POPUP.pid"

stop_monitor() {
  [ -r "$PID_FILE" ] || return 0
  pid="$(cat "$PID_FILE")"
  rm -f "$PID_FILE"
  case "$pid" in
    ''|*[!0-9]*) return 0 ;;
  esac
  if ps -p "$pid" -o command= 2>/dev/null | grep -q '/PopupDismiss '; then
    kill "$pid" 2>/dev/null || true
  fi
}

case "$ACTION" in
  stop)
    stop_monitor
    exit 0
    ;;
  start)
    for other in clock wifi battery volume music; do
      [ "$other" = "$POPUP" ] || "$0" stop "$other"
    done
    stop_monitor
    ;;
  *)
    exit 2
    ;;
esac

mkdir -p "$CACHE_DIR"
if [ ! -x "$BINARY" ] || [ "$SOURCE" -nt "$BINARY" ]; then
  xcrun swiftc "$SOURCE" -framework CoreGraphics -o "$BINARY" || exit 0
fi

printf '%s\n' "$$" > "$PID_FILE"
exec "$BINARY" "$POPUP" "$PID_FILE"
