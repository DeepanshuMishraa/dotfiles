package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"

	"github.com/dipxsy/hued/internal/adapter"
	"github.com/dipxsy/hued/internal/browser"
	"github.com/dipxsy/hued/internal/domain"
	"github.com/dipxsy/hued/internal/nativehost"
	"github.com/dipxsy/hued/internal/orchestrator"
	"github.com/dipxsy/hued/internal/paths"
	"github.com/dipxsy/hued/internal/repository"
	"github.com/dipxsy/hued/internal/state"
)

func main() {
	if filepath.Base(os.Args[0]) == "hued-browser-host" || nativeHostInvocation(os.Args[1:]) {
		resolved, err := paths.Resolve()
		if err == nil {
			err = nativehost.Run(filepath.Join(resolved.StateDir, "browser-theme.json"), os.Stdin, os.Stdout)
		}
		if err != nil {
			fmt.Fprintln(os.Stderr, "hued-browser-host:", err)
			os.Exit(1)
		}
		return
	}
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "hued:", err)
		os.Exit(1)
	}
}

func nativeHostInvocation(arguments []string) bool {
	for _, argument := range arguments {
		if strings.HasPrefix(argument, "chrome-extension://") {
			return true
		}
	}
	return false
}

func run(arguments []string) error {
	resolved, err := paths.Resolve()
	if err != nil {
		return err
	}
	themes := repository.NewThemes(resolved.ThemeDir)
	if len(arguments) == 0 {
		usage()
		return nil
	}
	if arguments[0] == "internal" {
		return runInternal(arguments[1:], resolved)
	}
	if err := themes.Seed(); err != nil {
		return err
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("resolve home directory: %w", err)
	}
	configHome := filepath.Dir(resolved.ConfigDir)
	targets := []adapter.Adapter{
		adapter.NewMacOS(),
		adapter.NewSketchyBar(configHome),
		adapter.NewHerdr(configHome),
		adapter.NewPi(home),
		adapter.NewNeovim(configHome),
		adapter.NewZed(configHome),
		adapter.NewTmux(configHome),
		adapter.NewGhostty(home, configHome, resolved.StateDir),
		adapter.NewOpenCode(configHome),
		adapter.NewTermy(configHome),
		adapter.NewObsidian(home),
		adapter.NewSpotify(configHome),
		adapter.NewRaycast(),
		adapter.NewBrowser(resolved.StateDir),
	}
	runner := orchestrator.New(resolved.StateDir, targets)

	switch arguments[0] {
	case "init":
		fmt.Println("initialized", resolved.ConfigDir)
		return nil
	case "list":
		return listThemes(themes, resolved.StateDir)
	case "status":
		return showStatus(resolved.StateDir)
	case "plan":
		return planTheme(arguments[1:], themes, runner)
	case "set":
		return setTheme(arguments[1:], themes, runner)
	case "doctor":
		return doctor(resolved, targets)
	case "browser":
		return browserCommand(arguments[1:], home, resolved.StateDir)
	case "help", "--help", "-h":
		usage()
		return nil
	default:
		return fmt.Errorf("unknown command %q; run `hued help`", arguments[0])
	}
}

func listThemes(themes repository.Themes, stateDir string) error {
	available, err := themes.List()
	if err != nil {
		return err
	}
	current, err := state.Read(stateDir)
	if err != nil {
		return err
	}
	for _, theme := range available {
		marker := ""
		if theme.Name == current.Theme {
			marker = " *"
		}
		fmt.Printf("%s%s\n", theme.Name, marker)
	}
	return nil
}

func showStatus(stateDir string) error {
	current, err := state.Read(stateDir)
	if err != nil {
		return err
	}
	if current.Theme == "" {
		fmt.Println("No Hued theme has been applied yet.")
		return nil
	}
	fmt.Println("theme:", current.Theme)
	fmt.Println("applied:", current.AppliedAt.Format("2006-01-02T15:04:05Z"))
	for _, result := range current.Results {
		fmt.Printf("%-10s %-24s %s\n", result.Adapter, result.Status, result.Detail)
	}
	return nil
}

func planTheme(arguments []string, themes repository.Themes, runner orchestrator.Orchestrator) error {
	if len(arguments) != 1 {
		return fmt.Errorf("usage: hued plan <theme>")
	}
	theme, err := themes.Load(arguments[0])
	if err != nil {
		return err
	}
	fmt.Printf("theme: %s (%s)\n", theme.Name, theme.Appearance)
	for _, action := range runner.Plan(theme) {
		fmt.Printf("%-10s %s\n", action.Adapter, action.Detail)
	}
	return nil
}

func setTheme(arguments []string, themes repository.Themes, runner orchestrator.Orchestrator) error {
	flags := flag.NewFlagSet("set", flag.ContinueOnError)
	dryRun := flags.Bool("dry-run", false, "show the plan without changing anything")
	only := flags.String("only", "", "apply only comma-separated adapters")
	if err := flags.Parse(arguments); err != nil {
		return err
	}
	if flags.NArg() != 1 {
		return fmt.Errorf("usage: hued set [--dry-run] [--only adapter,...] <theme>")
	}
	theme, err := themes.Load(flags.Arg(0))
	if err != nil {
		return err
	}
	runner, err = runner.Only(*only)
	if err != nil {
		return err
	}
	if *dryRun {
		fmt.Printf("theme: %s (%s)\n", theme.Name, theme.Appearance)
		for _, action := range runner.Plan(theme) {
			fmt.Printf("%-10s %s\n", action.Adapter, action.Detail)
		}
		return nil
	}
	results, err := runner.Apply(theme)
	for _, result := range results {
		fmt.Printf("%-10s %-24s %s\n", result.Adapter, result.Status, result.Detail)
	}
	if err != nil {
		return err
	}
	for _, result := range results {
		if result.Status == domain.ResultFailed {
			return fmt.Errorf("theme applied partially; failed adapters are listed above and prior state remains recoverable")
		}
	}
	return nil
}

func doctor(resolved paths.Paths, targets []adapter.Adapter) error {
	fmt.Println("config:", resolved.ConfigDir)
	fmt.Println("themes:", resolved.ThemeDir)
	fmt.Println("state:", resolved.StateDir)
	fmt.Println("platform:", runtime.GOOS+"/"+runtime.GOARCH)
	if browserID := defaultBrowserBundleID(); browserID != "" {
		fmt.Println("default browser:", browserID)
	} else {
		fmt.Println("default browser: unknown")
	}
	names := make([]string, 0, len(targets))
	for _, target := range targets {
		status := "not detected"
		if target.Detect() {
			status = "ready"
		}
		names = append(names, fmt.Sprintf("%-10s %s", target.Name(), status))
	}
	sort.Strings(names)
	for _, name := range names {
		fmt.Println(name)
	}
	return nil
}

func browserCommand(arguments []string, home, stateDir string) error {
	if len(arguments) == 0 || arguments[0] != "setup" {
		return fmt.Errorf("usage: hued browser setup --browser arc --extension-id <id>")
	}
	flags := flag.NewFlagSet("browser setup", flag.ContinueOnError)
	browserName := flags.String("browser", "arc", "browser name: arc, chrome, or chromium")
	id := flags.String("extension-id", "", "unpacked extension ID")
	if err := flags.Parse(arguments[1:]); err != nil {
		return err
	}
	path, err := browser.Setup(home, stateDir, *browserName, *id)
	if err != nil {
		return err
	}
	fmt.Println("native host:", path)
	fmt.Println("the extension will reconnect automatically; no browser restart is required")
	return nil
}

func runInternal(arguments []string, resolved paths.Paths) error {
	if len(arguments) == 0 {
		return fmt.Errorf("missing internal command")
	}
	switch arguments[0] {
	case "ghostty-reload":
		flags := flag.NewFlagSet("ghostty-reload", flag.ContinueOnError)
		logPath := flags.String("log", filepath.Join(resolved.StateDir, "ghostty-reload.log"), "reload log path")
		if err := flags.Parse(arguments[1:]); err != nil {
			return err
		}
		return adapter.RunGhosttyReload(*logPath)
	case "browser-host":
		return nativehost.Run(filepath.Join(resolved.StateDir, "browser-theme.json"), os.Stdin, os.Stdout)
	default:
		return fmt.Errorf("unknown internal command %q", arguments[0])
	}
}

func defaultBrowserBundleID() string {
	output, err := exec.Command("/usr/bin/defaults", "read", "com.apple.LaunchServices/com.apple.launchservices.secure", "LSHandlers").Output()
	if err != nil {
		return ""
	}
	pattern := regexp.MustCompile(`(?s)LSHandlerRoleAll = "?([^";]+)"?;\s+LSHandlerURLScheme = https;`)
	match := pattern.FindSubmatch(output)
	if len(match) != 2 {
		return ""
	}
	return strings.TrimSpace(string(match[1]))
}

func usage() {
	fmt.Print(`Hued coordinates one semantic color theme across macOS, apps, and websites.

Usage:
  hued init
  hued list
  hued status
  hued plan <theme>
  hued set [--dry-run] [--only adapter,...] <theme>
  hued doctor
  hued browser setup --browser arc --extension-id <id>
`)
}
