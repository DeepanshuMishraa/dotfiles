# Dotfiles Agent Guide

## Repository model

- This Git repository is rooted at `$HOME`, not in a conventional project directory.
- The root `.gitignore` ignores everything by default and allowlists selected dotfiles.
- Keep commands scoped to known tracked paths. Do not recursively inspect or modify the whole home directory.
- Preserve unrelated local files and machine-specific state.

## Configuration map

### Shell and command line

- `.config/fish/config.fish` is the small Fish entry point.
- `.config/fish/conf.d/` contains startup configuration split by concern.
- `.config/fish/functions/` contains autoloaded Fish functions.
- `.config/fish/completions/` contains command completions.
- `.config/starship.toml` defines the shell prompt.
- `.zshrc` and `.config/.zshrc` are retained Zsh configuration; Fish is the active shell.
- `.config/ripgrep/config` contains global ripgrep defaults.
- `.config/git/ignore` contains the global Git ignore rules.
- `.config/gh/config.yml` contains non-secret GitHub CLI preferences.
- `.config/envman/` contains environment-loading shell helpers.

### Dotfiles and packages

- `.config/dot` implements the `dot` management command.
- `.config/dot-packages/bundle` records Homebrew taps, formulas, and casks.
- `Scripts/` contains personal executable scripts.

### Editors and terminals

- `.config/nvim/init.lua` is the Neovim entry point; detailed guidance lives in `.config/nvim/AGENTS.md`.
- `.config/zed/settings.json` and `.config/zed/themes/` contain Zed preferences and themes.
- `.config/ghostty/config` is the Ghostty entry point; its scripts and themes live beside it.
- `.config/tmux/tmux.conf` is the tmux entry point; startup helpers live in the same directory.
- `.config/termy/config.txt`, `.config/termy/plugins/`, and `.config/termy/themes/` configure Termy.
- `.config/themes/` contains shared theme definitions used across tools.

### Desktop and system tools

- `.config/aerospace/aerospace.toml` configures the AeroSpace window manager.
- `.config/btop/btop.conf` and `.config/btop/themes/` configure btop.
- `.config/cmux/cmux.json` configures cmux.
- `.config/mole/clean-list.txt` is the intentional Mole cleanup configuration; logs are generated state.
- `.config/solana/install/config.yml` is Solana installer configuration. `.config/solana/id.json` is private identity material, not ordinary config.

### AI and development tools

- `.config/opencode/opencode.json` is the OpenCode entry point; `.config/opencode/AGENTS.md` and `LEARN.md` contain scoped instructions.
- `.agents/` and `.config/agents/` contain shared agent skills, including symlinks. Preserve link targets and avoid copying linked trees into the repository.
- `.config/herdr/config.toml` and `.config/herdr-dev/config.toml` configure stable and development Herdr environments.
- `.config/kilo/plugin/` contains Kilo plugins.
- `.config/tanstack/cli.json` contains TanStack CLI preferences.
- `.config/cagent/`, `.config/hunk/`, and similar state-oriented directories may contain tool-managed files; inspect ownership before editing.

When a nested `AGENTS.md` exists, its instructions take precedence within that subtree.

## Secrets

- Never commit credentials, tokens, private keys, authentication databases, or generated sessions.
- Local secrets live in `.config/dotfiles/secrets.env`.
- Fish loads them through `.config/fish/conf.d/secrets.fish`.
- Both files must remain ignored. Reference environment variables from tracked configs instead of hardcoding values.
- Treat GitHub CLI hosts data and Solana identity files as credentials, even when their format looks like ordinary YAML or JSON.
- Do not print secret values while inspecting or validating configuration.

## Editing conventions

- Make minimal changes and follow the structure already used by each tool.
- Use `$HOME` instead of hardcoded user paths where portability matters.
- Keep Fish configuration modular; add settings to the relevant `conf.d` file rather than growing `config.fish`.
- Edit the completion template inside `.config/dot`, then run `dot completions`; do not hand-edit `completions/dot.fish`.
- Keep the Homebrew bundle grouped as taps, formulas, then casks, with each group alphabetically sorted.
- Treat histories, logs, locks, caches, databases, backup snapshots, `.DS_Store`, and runtime state as generated files unless the user explicitly wants them versioned.
- Do not run `dot push`, install packages, change the default shell, or perform network operations without explicit user approval.

## Useful commands

```fish
dot help
dot doctor
dot check-packages
dot package list
dot completions
dot push "Commit message"
```

`dot push` stages all allowlisted changes, checks for likely secrets, commits, and pushes the current upstream branch.

## Validation

Run only the checks relevant to changed files:

```fish
bash -n ~/.config/dot
fish -n ~/.config/fish/conf.d/<changed-file>.fish
fish -n ~/.config/fish/functions/<changed-file>.fish
dot check-packages
git diff --check
```

Before committing, confirm ignored secret files are not tracked and review the staged file list.
