#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

wifi_device() {
  networksetup -listallhardwareports \
    | awk '/Hardware Port: (Wi-Fi|AirPort)/ { getline; print $2; exit }'
}

refresh() {
  device="$(wifi_device)"
  power="$(networksetup -getairportpower "$device" 2>/dev/null | awk '{ print $NF }')"
  ssid="$("$CONFIG_DIR/plugins/wifi_ssid.sh" 2>/dev/null)"
  if [ -z "$ssid" ]; then
    ssid="$(ipconfig getsummary "$device" 2>/dev/null | awk -F ' SSID : ' '/ SSID : / { print $2; exit }')"
  fi
  [ "$ssid" = "<redacted>" ] && ssid=""
  address="$(ipconfig getifaddr "$device" 2>/dev/null)"
  if [ -z "$address" ]; then
    address="$(networksetup -getinfo Wi-Fi 2>/dev/null \
      | awk -F': ' '/^IP address:/ { if ($2 != "none") print $2; exit }')"
  fi

  if [ "$power" != "On" ]; then
    connection="Wi-Fi Off"
    signal="Signal · Unavailable"
    toggle_label="Turn Wi-Fi On"
  elif [ -z "$ssid" ]; then
    connection="Not Connected"
    signal="Signal · Unavailable"
    toggle_label="Turn Wi-Fi Off"
  else
    rssi="$(osascript -l JavaScript \
      -e 'ObjC.import("CoreWLAN"); const i=$.CWWiFiClient.sharedWiFiClient.interface; i ? i.rssiValue : -100' \
      2>/dev/null)"
    case "$rssi" in
      -[0-9]|-[1-4][0-9]) strength="Excellent" ;;
      -5[0-9]) strength="Good" ;;
      -6[0-9]) strength="Fair" ;;
      *) strength="Weak" ;;
    esac

    gateway="$(route -n get default 2>/dev/null | awk '/gateway:/ { print $2; exit }')"
    network_type="$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar/wifi-network-type" 2>/dev/null)"
    if [ "$network_type" = "spairport_network_type_sharing" ] || [ "$gateway" = "172.20.10.1" ]; then
      connection="Hotspot · $ssid"
    else
      connection="Wi-Fi · $ssid"
    fi
    signal="Signal · $strength ($rssi dBm)"
    toggle_label="Turn Wi-Fi Off"
  fi

  [ -n "$address" ] || address="Unavailable"
  sketchybar --set wifi.connection label="$connection" \
             --set wifi.signal label="$signal" \
             --set wifi.address label="IP · $address" \
             --set wifi.toggle label="$toggle_label"
}

case "$1" in
  toggle)
    sketchybar --set battery popup.drawing=off \
               --set clock popup.drawing=off \
               --set volume popup.drawing=off \
               --set music popup.drawing=off
    if [ "$(sketchybar --query wifi | jq -r '.popup.drawing')" = "on" ]; then
      sketchybar --set wifi popup.drawing=off
      "$CONFIG_DIR/plugins/popup_dismiss.sh" stop wifi
    else
      refresh
      sketchybar --set wifi popup.drawing=on
      "$CONFIG_DIR/plugins/popup_dismiss.sh" start wifi >/dev/null 2>&1 &
    fi
    ;;
  power)
    device="$(wifi_device)"
    power="$(networksetup -getairportpower "$device" 2>/dev/null | awk '{ print $NF }')"
    if [ "$power" = "On" ]; then
      networksetup -setairportpower "$device" off
    else
      networksetup -setairportpower "$device" on
    fi
    sketchybar --set wifi popup.drawing=off
    "$CONFIG_DIR/plugins/popup_dismiss.sh" stop wifi
    NAME=wifi SENDER=forced "$CONFIG_DIR/plugins/wifi.sh"
    ;;
  settings)
    sketchybar --set wifi popup.drawing=off
    "$CONFIG_DIR/plugins/popup_dismiss.sh" stop wifi
    open 'x-apple.systempreferences:com.apple.wifi-settings-extension'
    ;;
esac
