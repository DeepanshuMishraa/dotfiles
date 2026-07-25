if status is-interactive
    # Navigation and Git
    alias cd 'z'
    alias dork 'ssh clawd@100.92.60.124'
    alias gs 'git status'
    alias gl 'git log --oneline --graph --decorate --all'
    alias gp 'git push'
    alias gc 'git commit -m'
    alias gpull 'git pull origin'

    # Development
    alias pd 'pnpm dev'
    alias cls clear
    alias bd 'bun run dev'
    alias scn 'pnpm dlx shadcn@latest'
    alias py python3
    alias oc 'opencode .'

    # Remote machines
    alias vps 'mosh ubuntu@149.56.15.51'
end
