#!/usr/bin/env bash
set -euo pipefail

# Ghostty runs this for every new terminal window.
# Start the macOS login shell first so interactive configuration is loaded
# exactly as in a normal terminal, then hand that terminal to herdr.

# Set window title to the current directory basename (project/folder name).
# Uses OSC 0 escape sequence — works even through exec because it goes to the
# terminal emulator directly.
label="${GHOSTTY_TITLE:-${PWD##*/}}"
printf '\033]0;%s\007' "$label"

user_name="${USER:-$(/usr/bin/id -un)}"
login_shell="$(/usr/bin/dscl . -read "/Users/${user_name}" UserShell 2>/dev/null | /usr/bin/awk '/^UserShell:/ { print $2; exit }' || true)"
if [[ -z "$login_shell" || ! -x "$login_shell" ]]; then
    login_shell="${SHELL:-/bin/zsh}"
fi

case "${login_shell##*/}" in
    fish)
        exec "$login_shell" --login --interactive --command 'exec /Users/dipxsy/Desktop/herdr/herdr'
        ;;
    *)
        exec "$login_shell" -lic 'exec /Users/dipxsy/Desktop/herdr/herdr'
        ;;
esac
