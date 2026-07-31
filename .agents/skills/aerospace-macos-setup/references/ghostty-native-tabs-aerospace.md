# Ghostty Native Tabs With AeroSpace

## Summary

Ghostty on macOS uses native macOS tabs. macOS exposes native tabs through the window-manager API as separate windows. AeroSpace, yabai, and similar tools consume that API, so they cannot reliably know whether Ghostty created a new tab or a new real window.

Result: Ghostty native tabs and AeroSpace tiling are not a stable combination.

## Symptoms Observed

- Creating Ghostty tabs made the visible terminal narrower, as if each tab was a separate tiled window.
- `Control+Tab` successfully switched Ghostty tabs but also caused the visible window to resize or jump monitors.
- One tab could become extremely narrow, taking full height but only a small fraction of the monitor width.
- Floating Ghostty prevented some tiling shrinkage but introduced frame-memory bugs: switching tabs flipped the same visual window between left/right half-screen frames or monitor-specific frames.
- Moving a single Ghostty "window" between monitors with `move-node-to-monitor` could inject it into the target monitor's visible workspace and make it half-screen if another window was already there.

## Official Workaround

Ghostty documents this limitation and suggests an AeroSpace rule:

```toml
[[on-window-detected]]
    if.app-id = 'com.mitchellh.ghostty'
    run = ['layout tiling']
```

If tabs are still rendered as separate windows, Ghostty docs say to try `layout floating`.

Observed tradeoff: `layout tiling` can still shrink/tile tabs as separate windows; `layout floating` can preserve bad per-tab frames and cause half-screen/full-screen flipping during tab switches.

## Known Bad Fixes

Do not use huge Ghostty window sizes:

```toml
window-width = 9999
window-height = 9999
maximize = true
```

Ghostty window size is in terminal grid cells. Oversized values produced bad monitor geometry, such as full width but missing the lower part of the screen.

Do not chain tab switching to `reset_window_size`:

```toml
keybind = ctrl+tab=next_tab
keybind = chain=reset_window_size
keybind = ctrl+shift+tab=previous_tab
keybind = chain=reset_window_size
```

This did not reliably fix native-tab geometry and added more state changes while switching tabs.

Do not rely on `layout floating` as a universal fix. It can make each native tab keep its own remembered floating frame.

## Settings That Can Help

This Ghostty setting is worth keeping:

```toml
window-save-state = never
```

It helps prevent bad saved window/tab frames from being restored after restart. It does not fix native-tab behavior while the current Ghostty process is running.

If the running Ghostty app already has broken frame state, the cleanest reset is usually:

1. Close all Ghostty windows/tabs.
2. Confirm `window-save-state = never`.
3. Relaunch Ghostty.
4. Avoid creating Ghostty native tabs while AeroSpace is managing windows.

## Better Stable Models

Use one of these instead of Ghostty native tabs under AeroSpace:

- Use one Ghostty OS window per AeroSpace workspace.
- Use Ghostty splits inside one tab/window.
- Use `tmux` windows and panes inside one Ghostty OS window.
- Use a terminal with non-native/custom tab UI if native tabs are mandatory.

## Monitor Movement Lesson

Use workspace movement for "throw this app/screen to another monitor":

```toml
ctrl-alt-shift-up = 'move-workspace-to-monitor --wrap-around up'
ctrl-alt-shift-down = 'move-workspace-to-monitor --wrap-around down'
ctrl-alt-shift-left = 'move-workspace-to-monitor --wrap-around left'
ctrl-alt-shift-right = 'move-workspace-to-monitor --wrap-around right'
```

Avoid using `move-node-to-monitor` for this mental model. It moves one window into whatever workspace is currently visible on the target monitor. If that workspace already contains a window, the moved app becomes half-screen or smaller.

## Debug Commands

Inspect the active state:

```bash
aerospace list-windows --all --format '%{window-id} | %{app-name} | %{window-title} | monitor=%{monitor-id} | workspace=%{workspace} | layout=%{window-layout} | parent=%{window-parent-container-layout} | root=%{workspace-root-container-layout}'
aerospace list-workspaces --all --format '%{workspace} | monitor=%{monitor-id} | focused=%{workspace-is-focused} | visible=%{workspace-is-visible}'
aerospace config --get mode.main.binding --json
```

Reset a workspace after accidental accordion or nested layout state:

```bash
aerospace layout tiles horizontal
aerospace flatten-workspace-tree
```
