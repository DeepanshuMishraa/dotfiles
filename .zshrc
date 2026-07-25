# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
# export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-autosuggestions)

# source $ZSH/oh-my-zsh.sh

# Terminal title: show current dir at prompt, running command during exec
precmd() { printf "\e]2;%s\a" "${PWD/#$HOME/~}" }
preexec() { printf "\e]2;%s\a" "${2%% *}" }

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias cd='z'
alias dork='ssh clawd@100.92.60.124'
alias gs='git status'
alias gl='git log --oneline --graph --decorate --all'
alias gp='git push'
alias gc='git commit -m'
alias gpull='git pull origin'
alias pd='pnpm dev'
alias cls=clear
alias bd='bun run dev'
alias scn='pnpm dlx shadcn@latest'
alias dps='(echo -e "CONTAINER ID\tIMAGE\tCREATED AT\tSTATUS\tNAMES" \
 && docker ps -a --format "{{.ID}}\t{{.Image}}\t{{.CreatedAt}}\t{{.Status}}\t{{.Names}}" \
 | sort -k3 -r) | column -t'
alias vps='mosh ubuntu@149.56.15.51'
alias py='python3'
alias oc='opencode .'
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"


# rust
export RUST_HOME="$HOME/.cargo/env"
case ":$PATH:" in
  *":$RUST_HOME:"*) ;;
  *) export PATH="$RUST_HOME:$PATH" ;;
esac
# rust end

eval "$(zoxide init zsh)"
# solana
export SOLANA_HOME="$HOME/.local/share/solana/install/active_release/bin"
case ":$PATH:" in
  *":$SOLANA_HOME:"*) ;;
  *) export PATH="$SOLANA_HOME:$PATH" ;;
esac
# solana end

export PATH="$HOME/.local/bin:$PATH"

# cre
export CRE_INSTALL="$HOME/.cre"
export PATH="$CRE_INSTALL/bin:$PATH"

#[[ -f "$HOME/.config/kaku/zsh/kaku.zsh" ]] && source "$HOME/.config/kaku/zsh/kaku.zsh" # Kaku Shell Integration
#export JAVA_HOME=$(/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home)
#export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
#export PATH="$JAVA_HOME/bin:$PATH"

# Android SDK
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export ANDROID_SDK_ROOT=/opt/homebrew/share/android-commandlinetools
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"

# Added by git-ai installer on Tue Apr 28 21:35:24 IST 2026
export PATH="/Users/dipxsy/.git-ai/bin:$PATH"


# bun completions
[ -s "/Users/dipxsy/.bun/_bun" ] && source "/Users/dipxsy/.bun/_bun"


# Added by Antigravity CLI installer
export PATH="/Users/dipxsy/.local/bin:$PATH"

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
export PATH=$PATH:$HOME/go/bin

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"

# Battery remaining time & percentage
alias battery='pmset -g batt | grep -oE "[0-9]+%;.*[0-9]+:[0-9]+ remaining" | sed "s/ discharging; //"'

# Stop all running Docker containers
alias dkill='docker stop $(docker ps -q)'

# Update everything: pi, extensions, and homebrew
alias upgrade='pi update && pi update --extensions && brew upgrade'

# Power management (note: overrides standard `sleep` command)
alias sleep='sudo pmset -a disablesleep 0'
alias wake='sudo pmset -a disablesleep 1'

# >>> railway initialize >>>
source "$HOME/.railway/env"
# <<< railway initialize <<<

# Load local credentials kept outside Git.
if [[ -r "$HOME/.config/dotfiles/secrets.env" ]]; then
  source "$HOME/.config/dotfiles/secrets.env"
fi

# Claude Code UI/tooling backed by Codex OAuth through local CLIProxyAPI.
alias claudex='env -u ANTHROPIC_API_KEY ANTHROPIC_BASE_URL=http://127.0.0.1:8317 ANTHROPIC_AUTH_TOKEN=claudex-local CLAUDE_CODE_SUBAGENT_MODEL=gpt-5.6-sol CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1 CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3 ENABLE_TOOL_SEARCH=false claude --model gpt-5.6-sol'

eval "$(starship init zsh)"
