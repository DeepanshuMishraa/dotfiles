#!/usr/bin/env bash
set -u

section() {
  printf '\n== %s ==\n' "$1"
}

run() {
  printf '$ %s\n' "$*"
  "$@" 2>&1 || true
}

section "Binary"
run command -v aerospace
run aerospace --version

section "Config"
run aerospace config --config-path
run aerospace config --get mode.main.binding --json

section "Displays"
run aerospace list-monitors
run aerospace list-monitors --focused

section "Focused Window"
run aerospace list-windows --focused --format '%{window-id} | %{app-name} | %{window-title} | monitor=%{monitor-id} | workspace=%{workspace}'

section "Process"
run pgrep -fl AeroSpace

section "Recent Logs"
run /usr/bin/log show --last 2m --predicate 'process == "AeroSpace" OR eventMessage CONTAINS "AeroSpace"'
