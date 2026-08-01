package adapter

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"

	"github.com/dipxsy/hued/internal/domain"
	"github.com/dipxsy/hued/internal/files"
)

type Tmux struct {
	path string
}

func NewTmux(configDir string) *Tmux {
	return &Tmux{path: filepath.Join(configDir, "tmux", "tmux.conf")}
}

func (tmux *Tmux) Name() string { return "tmux" }
func (tmux *Tmux) Detect() bool { _, err := os.Stat(tmux.path); return err == nil }
func (tmux *Tmux) Plan(_ domain.Theme) Action {
	return Action{Adapter: tmux.Name(), Detail: tmux.path + " + live source-file"}
}
func (tmux *Tmux) Apply(theme domain.Theme) domain.Result {
	if theme.Targets.TmuxFlavour == nil || *theme.Targets.TmuxFlavour == "" {
		return domain.Result{Adapter: tmux.Name(), Status: domain.ResultUnsupported, Detail: "theme has no Catppuccin tmux flavour"}
	}
	content, err := os.ReadFile(tmux.path)
	if err != nil {
		return failed(tmux.Name(), "read config", err)
	}
	pattern := regexp.MustCompile(`(?m)^(\s*set(?:-option)?\s+-g\s+@catppuccin_flavour\s+)(['"]?)[^'"\s]+['"]?(.*)$`)
	if !pattern.Match(content) {
		return failed(tmux.Name(), "update config", fmt.Errorf("@catppuccin_flavour is not configured"))
	}
	replacement := []byte("${1}'" + *theme.Targets.TmuxFlavour + "'${3}")
	if err := files.WriteAtomic(tmux.path, pattern.ReplaceAll(content, replacement), fileMode(tmux.path)); err != nil {
		return failed(tmux.Name(), "write config", err)
	}
	if binary, err := exec.LookPath("tmux"); err == nil && exec.Command(binary, "list-sessions").Run() == nil {
		if output, reloadErr := exec.Command(binary, "source-file", tmux.path).CombinedOutput(); reloadErr != nil {
			return failed(tmux.Name(), "config updated but live reload failed", fmt.Errorf("%v: %s", reloadErr, output))
		}
	}
	return applied(tmux.Name(), tmux.path+"; sourced running server")
}
