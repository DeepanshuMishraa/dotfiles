function __xrun_watch_snapshot --argument-names root
    command find $root \
        -type d \( -name .git -o -name .build -o -name build -o -name DerivedData \) -prune -o \
        -type f \( \
            -name '*.swift' -o -name '*.m' -o -name '*.mm' -o -name '*.h' -o \
            -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.metal' -o \
            -name '*.storyboard' -o -name '*.xib' -o -name '*.plist' -o \
            -name '*.xcconfig' -o -name '*.entitlements' -o -name '*.strings' -o \
            -name '*.stringsdict' -o -name '*.json' -o -name '*.png' -o \
            -name '*.jpg' -o -name '*.jpeg' -o -name '*.pdf' -o -name '*.svg' -o \
            -name '*.mlmodel' -o -path '*.xcassets/*' -o -path '*.xcdatamodeld/*' -o \
            -name project.pbxproj -o -name Package.resolved \
        \) -exec stat -f '%m:%z:%N' {} + 2>/dev/null |
        command shasum |
        string split -f1 ' '
end

function __xrun_stop_app --argument-names platform simulator_id bundle_id
    if test -z "$bundle_id"
        return
    end

    if test "$platform" = mac
        command osascript -e "tell application id \"$bundle_id\" to quit" 2>/dev/null
    else if test -n "$simulator_id"
        command xcrun simctl terminate $simulator_id $bundle_id >/dev/null 2>&1
    end
end

function __xrun_arm_interrupt --argument-names platform bundle_id simulator_id
    functions -e __xrun_interrupt_handler
    set -e -g __xrun_interrupted
    set -g __xrun_interrupt_platform $platform
    set -g __xrun_interrupt_bundle_id $bundle_id
    set -g __xrun_interrupt_simulator_id $simulator_id
    if test -z "$__xrun_interrupt_simulator_id"
        set -g __xrun_interrupt_simulator_id -
    end

    function __xrun_interrupt_handler --on-signal INT
        __xrun_stop_app \
            $__xrun_interrupt_platform \
            $__xrun_interrupt_simulator_id \
            $__xrun_interrupt_bundle_id
        set -g __xrun_interrupted 1
        functions -e __xrun_interrupt_handler
    end
end

function __xrun_disarm_interrupt
    functions -e __xrun_interrupt_handler
    set -e -g __xrun_interrupt_platform
    set -e -g __xrun_interrupt_simulator_id
    set -e -g __xrun_interrupt_bundle_id
    set -e -g __xrun_interrupted
end

function xrun --description "Build and run the current Swift or Xcode project"
    set -l original_argv $argv

    if contains -- -h $argv; or contains -- --help $argv
        echo "Usage: xrun [--mac | --ios] [--once] [--scheme NAME] [SCHEME]"
        echo "Build, open, and rebuild the current macOS or iPhone app when files change."
        return
    end

    set -l project_dir $PWD
    set -l container_args
    set -l container_name

    while test "$project_dir" != /
        set -l workspaces $project_dir/*.xcworkspace
        set -l projects $project_dir/*.xcodeproj

        if test (count $workspaces) -gt 0
            set container_args -workspace $workspaces[1]
            set container_name (path change-extension '' (path basename $workspaces[1]))
            break
        end

        if test (count $projects) -gt 0
            set container_args -project $projects[1]
            set container_name (path change-extension '' (path basename $projects[1]))
            break
        end

        if test -f $project_dir/Package.swift
            # SwiftPM does not understand xrun's runner-only flags. A package
            # executable already runs once, so strip them before forwarding.
            set -l package_args
            for argument in $original_argv
                if not contains -- $argument --once --mac --ios
                    set -a package_args $argument
                end
            end
            command swift run $package_args
            return $status
        end

        set project_dir (path dirname $project_dir)
    end

    if test (count $container_args) -eq 0
        echo "xrun: no .xcworkspace, .xcodeproj, or Package.swift found in this directory or its parents" >&2
        return 1
    end

    argparse 'h/help' 'm/mac' 'i/ios' 'o/once' 's/scheme=' -- $argv
    or return

    if set -q _flag_mac; and set -q _flag_ios
        echo "xrun: choose either --mac or --ios, not both" >&2
        return 2
    end

    if test (count $argv) -gt 1
        echo "xrun: expected at most one scheme name" >&2
        return 2
    end

    if not command -q xcodebuild; or not command -q xcrun; or not command -q jq
        echo "xrun: xcodebuild, xcrun, and jq must be installed and available on PATH" >&2
        return 1
    end

    set -l scheme
    if set -q _flag_scheme
        set scheme $_flag_scheme
    else if test (count $argv) -eq 1
        set scheme $argv[1]
    else
        set -l schemes (command xcodebuild $container_args -list -json 2>/dev/null |
            command jq -r '(.workspace.schemes // .project.schemes // [])[]')

        if test (count $schemes) -eq 0
            echo "xrun: no shared schemes found in "(string join ' ' $container_args) >&2
            return 1
        end

        if contains -- $container_name $schemes
            set scheme $container_name
        else if test (count $schemes) -eq 1
            set scheme $schemes[1]
        else if command -q fzf
            set scheme (printf '%s\n' $schemes | fzf --prompt='Scheme › ' --height=~40% --reverse)
            or return 130
        else
            echo "xrun: multiple schemes found; pass one with --scheme NAME" >&2
            printf '  %s\n' $schemes >&2
            return 1
        end
    end

    set -l settings (command xcodebuild $container_args -scheme $scheme -showBuildSettings -json 2>/dev/null)
    if test $status -ne 0; or test -z "$settings"
        echo "xrun: could not read build settings for scheme '$scheme'" >&2
        return 1
    end

    set -l supported_platforms (printf '%s\n' $settings |
        command jq -r '[.[].buildSettings.SUPPORTED_PLATFORMS // ""] | join(" ")')
    set -l platform

    if set -q _flag_mac
        set platform mac
    else if set -q _flag_ios
        set platform ios
    else
        set -l choices
        string match -q '*macosx*' -- $supported_platforms; and set -a choices mac
        string match -q '*iphonesimulator*' -- $supported_platforms; and set -a choices ios

        if test (count $choices) -eq 1
            set platform $choices[1]
        else if test (count $choices) -gt 1; and command -q fzf
            set platform (printf 'mac\nios\n' | fzf --prompt='Run on › ' --height=~40% --reverse)
            or return 130
        else if test (count $choices) -gt 1
            echo "xrun: this scheme supports macOS and iPhone; pass --mac or --ios" >&2
            return 1
        else
            echo "xrun: scheme '$scheme' does not build a macOS or iPhone app" >&2
            return 1
        end
    end

    if test "$platform" = mac; and not string match -q '*macosx*' -- $supported_platforms
        echo "xrun: scheme '$scheme' does not support macOS" >&2
        return 1
    end

    if test "$platform" = ios; and not string match -q '*iphonesimulator*' -- $supported_platforms
        echo "xrun: scheme '$scheme' does not support the iPhone Simulator" >&2
        return 1
    end

    set -l destination platform=macOS
    set -l simulator_id
    set -l active_bundle_id

    if test "$platform" = ios
        set simulator_id (command xcrun simctl list devices available -j |
            command jq -r '(
                [.devices[][] | select(
                    .state == "Booted" and
                    (.deviceTypeIdentifier | contains("iPhone"))
                )] +
                [.devices[][] | select(
                    .state == "Shutdown" and
                    (.deviceTypeIdentifier | contains("iPhone"))
                )]
            ) | first | .udid // empty')

        if test -z "$simulator_id"
            set -l runtime_id (command xcrun simctl list runtimes -j |
                command jq -r '[
                    .runtimes[] |
                    select(.isAvailable and (.identifier | contains("SimRuntime.iOS-")))
                ] | sort_by(.version | split(".") | map(tonumber)) | last | .identifier // empty')
            set -l device_type (command xcrun simctl list devicetypes -j |
                command jq -r 'first(
                    .devicetypes[] | select(.productFamily == "iPhone")
                ) | .identifier // empty')

            if test -z "$runtime_id"; or test -z "$device_type"
                echo "xrun: no iPhone Simulator runtime is installed; install one in Xcode Settings > Components" >&2
                return 1
            end

            set simulator_id (command xcrun simctl create 'xrun iPhone' $device_type $runtime_id)
            or begin
                echo "xrun: could not create an iPhone Simulator" >&2
                return 1
            end
        end

        set -l simulator_state (command xcrun simctl list devices -j |
            command jq -r --arg id $simulator_id '.devices[][] | select(.udid == $id) | .state')
        if test "$simulator_state" != Booted
            command xcrun simctl boot $simulator_id
            or return
        end

        command open -a Simulator
        command xcrun simctl bootstatus $simulator_id -b
        or return
        set destination "platform=iOS Simulator,id=$simulator_id"
    end

    while true
        echo "Building '$scheme' for $destination…"
        command xcodebuild $container_args -scheme $scheme -configuration Debug \
            -destination $destination -skipPackagePluginValidation build
        set -l build_status $status

        if test $build_status -eq 130
            __xrun_stop_app $platform $simulator_id $active_bundle_id
            return 130
        end

        if test $build_status -eq 0
            set settings (command xcodebuild $container_args -scheme $scheme -configuration Debug \
                -destination $destination -showBuildSettings -json 2>/dev/null)
            or begin
                echo "xrun: build succeeded, but its app path could not be resolved" >&2
                return 1
            end

            set -l app_path (printf '%s\n' $settings | command jq -r 'first(
                .[] | select(.buildSettings.PRODUCT_TYPE == "com.apple.product-type.application")
            ) | "\(.buildSettings.TARGET_BUILD_DIR)/\(.buildSettings.FULL_PRODUCT_NAME)" // empty')
            set -l bundle_id (printf '%s\n' $settings | command jq -r 'first(
                .[] | select(.buildSettings.PRODUCT_TYPE == "com.apple.product-type.application")
            ) | .buildSettings.PRODUCT_BUNDLE_IDENTIFIER // empty')

            if test -z "$app_path"; or not test -d "$app_path"
                echo "xrun: build succeeded, but no runnable .app product was found" >&2
                return 1
            end

            if test "$platform" = mac
                if test -n "$bundle_id"
                    command osascript -e "tell application id \"$bundle_id\" to quit" 2>/dev/null
                    command sleep 0.2
                end
                command open $app_path
                or return
                set active_bundle_id $bundle_id
            else
                if test -z "$bundle_id"
                    echo "xrun: build succeeded, but the app bundle identifier could not be resolved" >&2
                    return 1
                end

                command xcrun simctl install $simulator_id $app_path
                or return
                command xcrun simctl launch --terminate-running-process $simulator_id $bundle_id
                or return
                set active_bundle_id $bundle_id
            end
        else
            echo "xrun: build failed; waiting for another change…" >&2
        end

        if set -q _flag_once
            return $build_status
        end

        set -l snapshot (__xrun_watch_snapshot $project_dir)
        echo "Watching $project_dir — press Ctrl-C to stop."
        __xrun_arm_interrupt $platform $active_bundle_id $simulator_id

        while true
            command sleep 0.5
            set -l wait_status $status

            if set -q __xrun_interrupted
                __xrun_disarm_interrupt
                return 130
            else if test $wait_status -ne 0
                __xrun_stop_app $platform $simulator_id $active_bundle_id
                __xrun_disarm_interrupt
                return 130
            end

            set -l next_snapshot (__xrun_watch_snapshot $project_dir)
            if test "$next_snapshot" != "$snapshot"
                __xrun_disarm_interrupt
                command sleep 0.2
                echo "Change detected. Rebuilding…"
                break
            end
        end
    end
end
