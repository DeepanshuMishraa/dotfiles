# tmux Inside Ghostty Under AeroSpace

## Goal

Use one Ghostty OS window managed by AeroSpace, and put terminal "tabs" and panes inside tmux. This avoids Ghostty native macOS tabs, which are exposed to AeroSpace as separate windows.

## Mental Model

- AeroSpace manages OS windows and workspaces.
- Ghostty provides one terminal window.
- tmux runs inside that terminal and manages terminal workspaces.
- tmux "windows" are the closest equivalent to terminal tabs.
- tmux "panes" are splits inside a tmux window.

## First Session

Start a named tmux session:

```bash
tmux new -s main
```

Detach without killing it:

```text
Ctrl-b d
```

Reattach later:

```bash
tmux attach -t main
```

List sessions:

```bash
tmux ls
```

## Core Shortcuts

tmux commands start with a prefix. Default prefix:

```text
Ctrl-b
```

After pressing `Ctrl-b`, press:

```text
c       create new tmux window
n       next tmux window
p       previous tmux window
0-9     jump to tmux window by number
,       rename current tmux window
%       split pane vertically
"       split pane horizontally
arrow   move between panes
x       close pane
d       detach session
?       show help
```

## Why This Is Better Here

tmux windows do not create macOS windows. AeroSpace sees only the one Ghostty OS window, so switching between tmux windows does not resize Ghostty, move it between monitors, or create half-screen native-tab frames.

## Practical Rule

Avoid `Cmd+T` in Ghostty while using AeroSpace. Use `Ctrl-b c` for a new tmux "tab" instead.

Use AeroSpace for monitor/workspace placement:

```text
Control + Option + Shift + Arrow
```

Use tmux for terminal tabs/panes:

```text
Ctrl-b c
Ctrl-b n
Ctrl-b p
Ctrl-b %
Ctrl-b "
```
