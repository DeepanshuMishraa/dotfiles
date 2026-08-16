#!/usr/bin/env bash
# JankyBorders launcher (login item via launchd: com.dipxsy.jankyborders).
# Delegates to the Hued-managed script so `hued set` keeps colors in sync.
exec bash "$HOME/.config/aerospace/borders.sh"
