function xcrun --description "Run Apple developer tools or scaffold a SwiftUI app"
    if test (count $argv) -eq 0; or contains -- $argv[1] help -h --help
        echo "Usage: xcrun <command>"
        echo
        echo "Commands:"
        echo "  new [NAME | .]  Scaffold a SwiftUI app"
        echo "  watch [OPTIONS] Build, launch, and rebuild on changes"
        echo "  help            Show this help"
        return
    end

    if test "$argv[1]" = watch
        xrun $argv[2..]
        return $status
    end

    if test "$argv[1]" != new
        command xcrun $argv
        return $status
    end

    if contains -- -h $argv; or contains -- --help $argv
        echo "Usage: xcrun new [NAME | .]"
        echo "Scaffold a SwiftUI app for any Apple platform."
        return
    end

    if test (count $argv) -gt 2
        echo "xcrun new: expected an app name or '.'" >&2
        return 2
    end

    if not command -q xcodegen
        echo "xcrun new: xcodegen is required; install it with 'brew install xcodegen'" >&2
        return 1
    end

    if not command -q fzf
        echo "xcrun new: fzf is required for platform selection; install it with 'brew install fzf'" >&2
        return 1
    end

    set -l location
    if test (count $argv) -eq 2
        set location $argv[2]
    else
        read --prompt-str "App name (or . for the current directory): " location
        or return 130
    end

    if test -z "$location"
        echo "xcrun new: app name cannot be empty" >&2
        return 2
    end

    set -l target_dir
    set -l app_name

    if test "$location" = .
        set target_dir $PWD
        set app_name (path basename $target_dir | string replace -ar '[^A-Za-z0-9_]' '_')

        if string match -qr '^[0-9]' -- $app_name
            set app_name App_$app_name
        end

        if test -z "$app_name"
            set app_name SwiftUIApp
        end
    else
        if not string match -qr '^[A-Za-z][A-Za-z0-9_-]*$' -- $location
            echo "xcrun new: use letters, numbers, hyphens, and underscores; the name must start with a letter" >&2
            return 2
        end

        set app_name $location
        set target_dir $PWD/$location

        if test -e $target_dir
            echo "xcrun new: '$target_dir' already exists; no files were changed" >&2
            return 1
        end
    end

    for path_to_check in \
        $target_dir/project.yml \
        $target_dir/Sources \
        "$target_dir/$app_name.xcodeproj"
        if test -e $path_to_check
            echo "xcrun new: '$path_to_check' already exists; no files were changed" >&2
            return 1
        end
    end

    set -l platform_choice (printf '%s\n' \
        'iOS — iPhone & iPad' \
        'macOS — Mac' \
        'tvOS — Apple TV' \
        'watchOS — Apple Watch' \
        'visionOS — Apple Vision Pro' |
        fzf --prompt='Platform › ' --height=~50% --reverse --border --no-multi)
    or return 130
    set platform_choice $platform_choice[1]

    set -l platform
    set -l platform_label
    set -l deployment_target
    set -l product_type application
    switch $platform_choice
        case 'iOS — iPhone & iPad'
            set platform iOS
            set platform_label 'iOS'
            set deployment_target 17.0
        case 'macOS — Mac'
            set platform macOS
            set platform_label 'macOS'
            set deployment_target 14.0
        case 'tvOS — Apple TV'
            set platform tvOS
            set platform_label 'tvOS'
            set deployment_target 17.0
        case 'watchOS — Apple Watch'
            set platform watchOS
            set platform_label 'watchOS'
            set deployment_target 10.0
            set product_type application.watchapp2
        case 'visionOS — Apple Vision Pro'
            set platform visionOS
            set platform_label 'visionOS'
            set deployment_target 1.0
        case '*'
            echo "xcrun new: no platform selected; no files were changed" >&2
            return 2
    end

    set -l bundle_name (string lower -- $app_name | string replace -ar '_' '-')
    set -l bundle_id com.local.$bundle_name
    set -l app_type (string replace -ar '[^A-Za-z0-9_]' '_' -- $app_name)'App'

    command mkdir -p $target_dir/Sources
    or return

    printf '%s\n' \
        'import SwiftUI' \
        '' \
        '@main' \
        "struct $app_type: App {" \
        '    var body: some Scene {' \
        '        WindowGroup {' \
        '            ContentView()' \
        '        }' \
        '    }' \
        '}' >$target_dir/Sources/$app_type.swift
    or return

    printf '%s\n' \
        'import SwiftUI' \
        '' \
        'struct ContentView: View {' \
        '    var body: some View {' \
        '        VStack(spacing: 12) {' \
        '            Image(systemName: "swift")' \
        '                .font(.system(size: 48))' \
        '                .foregroundStyle(.orange)' \
        '' \
        '            Text("Hello, world!")' \
        '                .font(.title)' \
        '        }' \
        '        .padding()' \
        '    }' \
        '}' >$target_dir/Sources/ContentView.swift
    or return

    if not test -e $target_dir/.gitignore
        printf '%s\n' \
            '.DS_Store' \
            'DerivedData/' \
            '*.xcuserstate' \
            'xcuserdata/' >$target_dir/.gitignore
        or return
    end

    printf '%s\n' \
        "name: $app_name" \
        'options:' \
        '  createIntermediateGroups: true' \
        'settings:' \
        '  base:' \
        '    SWIFT_VERSION: 6.0' \
        '    MARKETING_VERSION: 1.0' \
        '    CURRENT_PROJECT_VERSION: 1' \
        'targets:' \
        "  $app_name:" \
        "    type: $product_type" \
        "    platform: $platform" \
        "    deploymentTarget: \"$deployment_target\"" \
        '    sources:' \
        '      - Sources' \
        '    settings:' \
        '      base:' \
        "        PRODUCT_BUNDLE_IDENTIFIER: $bundle_id" \
        '        GENERATE_INFOPLIST_FILE: YES' >$target_dir/project.yml
    or return

    if contains -- $platform iOS tvOS visionOS
        printf '%s\n' \
            '        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES' \
            '        INFOPLIST_KEY_UILaunchScreen_Generation: YES' >>$target_dir/project.yml
        or return
    end

    if test "$platform" = iOS
        printf '%s\n' \
            '        TARGETED_DEVICE_FAMILY: "1,2"' >>$target_dir/project.yml
        or return
    end

    command xcodegen --spec $target_dir/project.yml --project $target_dir
    or begin
        echo "xcrun new: project generation failed; the template files remain in '$target_dir'" >&2
        return 1
    end

    echo
    echo "Created $platform_label SwiftUI app '$app_name' in $target_dir"
    if test "$location" != .
        echo "  cd $location"
    end
    if contains -- $platform iOS macOS
        echo "  xrun"
    else
        echo "  open $app_name.xcodeproj"
    end
end
