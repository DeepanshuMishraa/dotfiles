# Hued

Hued applies one semantic color palette across macOS, local apps, terminals, editors, agents, and websites.

## Commands

```sh
hued list
hued plan rose-pine
hued set rose-pine
hued set --only ghostty,browser rose-pine
hued status
hued doctor
```

Bundled themes are installed at `~/.config/hued/themes/bundled`. Put personal manifests in `~/.config/hued/themes/custom`; a custom theme with the same `name` overrides its bundled counterpart.

## Live-update contract

`hued set` updates every detected adapter without asking the user to quit or restart an app.

| Target | Live mechanism |
| --- | --- |
| macOS | System Events changes appearance and the nearest supported named highlight color; wallpaper is always preserved |
| Rift Borders | Dedicated background service watches Hued's active theme color |
| SketchyBar | Generated semantic color palette plus live config reload |
| Ghostty | Atomic theme/config writes, then the proven delayed `SIGUSR1` (`killall -31 ghostty`) sequence |
| Neovim | Directory watcher reloads generated highlights after every atomic replacement |
| Zed | Built-in settings and theme file watchers |
| Termy | Built-in configuration watcher |
| tmux | `source-file` on the running server |
| Herdr | `herdr server reload-config` |
| OpenCode | `SIGUSR2` reload signal |
| Pi | Built-in custom-theme watcher |
| Obsidian | High-specificity enabled CSS snippet in every registered vault; Obsidian watches snippets |
| Spotify | Generated `[hued]` scheme inside the active Spicetify theme plus `spicetify -n refresh`; existing theme CSS/layout stays selected |
| Raycast | Persistently follows Hued's macOS light/dark appearance; private theme data is never modified |
| Websites | Native-messaging stream broadcasts the palette into already-open tabs |

If an app is not running, Hued writes its durable configuration and the app starts with that theme later. A failed adapter is reported explicitly; it is never presented as successful.

## Ghostty

Ghostty is intentionally special. Hued preserves the working two-config setup:

1. Write the complete generated theme to the existing `~/.config/ghostty/themes/herdr-global` path.
2. Keep the XDG config's `background` synchronized.
3. Point `~/Library/Application Support/com.mitchellh.ghostty/config` at the generated theme using an absolute path. This later-loaded macOS config wins deterministically.
4. Finish the main apply and persist state.
5. Start a detached helper, wait 500 ms, then send signal 31 (`SIGUSR1`) to Ghostty.

The helper timing matters: signaling from the foreground command was the source of the previous unreliable reload behavior. Its last result is written to `~/.local/state/hued/ghostty-reload.log`.

## Browser extension

The extension uses a Manifest V3 service worker, a native-messaging host, and content scripts. The Go host watches `~/.local/state/hued/browser-theme.json`; each write is pushed to the extension, stored, and broadcast to open tabs. A conservative computed-style engine maps neutral surfaces, text, and borders while preserving media and brand colors. Exact adapters cover GitHub, Notion, LinkedIn, X/Twitter, and YouTube. The popup can disable Hued per domain.

For Arc:

1. Open `arc://extensions`, enable Developer mode, and load `~/.config/hued/browser` unpacked.
2. Copy the generated extension ID.
3. Run `hued browser setup --browser arc --extension-id <id>`.

Arc currently discovers macOS native hosts through the Google Chrome-branded user registry. Hued handles this automatically.

The extension reconnects automatically using both a live retry and a persistent service-worker alarm. Chromium-protected pages, extension stores, browser chrome, cross-origin frames without host access, and closed shadow roots cannot be styled by an extension.

## Raycast

Raycast safely follows Hued's macOS light/dark appearance. Exact custom palettes require Raycast Pro's Theme Studio, and Raycast does not expose a supported background API for importing and selecting arbitrary themes. Hued deliberately does not modify Raycast's private encrypted database. See [the integration research](docs/web-theming-and-raycast.md).

## Development

```sh
go test ./...
go vet ./...
go build -o ~/.local/bin/hued ./cmd/hued
```
