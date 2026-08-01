function __hued_needs_command
    not __fish_seen_subcommand_from init list status plan set doctor browser help
end

complete -c hued -f -n __hued_needs_command -a init -d 'Initialize Hued themes'
complete -c hued -f -n __hued_needs_command -a list -d 'List themes'
complete -c hued -f -n __hued_needs_command -a status -d 'Show the last apply result'
complete -c hued -f -n __hued_needs_command -a plan -d 'Preview detected changes'
complete -c hued -f -n __hued_needs_command -a set -d 'Apply a theme live'
complete -c hued -f -n __hued_needs_command -a doctor -d 'Show target readiness'
complete -c hued -f -n __hued_needs_command -a browser -d 'Configure the browser bridge'
complete -c hued -f -n __hued_needs_command -a help -d 'Show help'

complete -c hued -f -n '__fish_seen_subcommand_from plan set' -a '(command hued list 2>/dev/null | string replace -r " \\*$" "")'
complete -c hued -n '__fish_seen_subcommand_from set' -l dry-run -d 'Show changes without applying'
complete -c hued -n '__fish_seen_subcommand_from set' -l only -x -d 'Apply comma-separated adapters'
complete -c hued -f -n '__fish_seen_subcommand_from browser; and not __fish_seen_subcommand_from setup' -a setup -d 'Install the native messaging host'
complete -c hued -n '__fish_seen_subcommand_from browser; and __fish_seen_subcommand_from setup' -l browser -x -a 'arc chrome chromium'
complete -c hued -n '__fish_seen_subcommand_from browser; and __fish_seen_subcommand_from setup' -l extension-id -x
