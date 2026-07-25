function fish_title
    set -l current_command (status current-command)

    if test "$current_command" = fish
        string replace -- "$HOME" '~' "$PWD"
    else
        echo "$current_command"
    end
end
