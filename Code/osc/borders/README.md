# Rift Borders

Native per-window borders for Rift on macOS 26+. This is a focused replacement
for JankyBorders: every visible window in the active Rift workspace gets an
inactive border, while the WindowServer-focused window gets the active style.

## Build

```sh
swift test
swift build -c release
```

The resulting binary is `.build/release/rift-borders`. Put it somewhere on
`PATH`, then copy `config.toml.example` to
`~/.config/rift-borders/config.toml` and run:

```sh
rift-borders validate
rift-borders service start
rift-borders status
rift-borders reload
rift-borders service stop
```

`rift-borders start`, `stop`, `restart`, and `status` are shortcuts for the
matching service commands. The service is a per-user launchd agent, so it
continues running without a terminal and is restarted by launchd if it exits.
`rift-borders config reload` is also accepted as the explicit configuration
reload form. Hued theme changes are watched automatically; changing themes
with `hued set <theme>` refreshes the borders from the selected palette.

The daemon uses private SkyLight notifications, like JankyBorders, and does
not use Accessibility APIs. Private APIs are macOS-version-sensitive; this
project targets macOS 26+.

## Rift startup

Add the following to Rift's `run_on_start` once the binary is on `PATH`:

```toml
run_on_start = ["exec-and-forget rift-borders service start"]
```

The launch agent is `~/Library/LaunchAgents/com.dipxsy.rift-borders.plist`.
The daemon keeps its PID at `~/.config/rift-borders/rift-borders.pid` so it can
be reloaded or stopped without killing unrelated processes.

## Configuration

See `config.toml.example` for active/inactive colors, width, gap, shape,
radius, gradients, glow, HiDPI rendering, application overrides, exclusions,
fullscreen handling, notch covering, and animation settings.
