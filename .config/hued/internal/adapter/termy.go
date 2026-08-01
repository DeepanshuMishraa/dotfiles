package adapter

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/dipxsy/hued/internal/domain"
	"github.com/dipxsy/hued/internal/files"
)

type Termy struct {
	configDir string
	path      string
}

func NewTermy(configDir string) *Termy {
	return &Termy{configDir: configDir, path: filepath.Join(configDir, "termy", "config.txt")}
}

func (termy *Termy) Name() string { return "termy" }
func (termy *Termy) Detect() bool { _, err := os.Stat(termy.path); return err == nil }
func (termy *Termy) Plan(_ domain.Theme) Action {
	return Action{Adapter: termy.Name(), Detail: termy.path + " + built-in file watcher reload"}
}
func (termy *Termy) Apply(theme domain.Theme) domain.Result {
	colors := termyColors(theme)
	content, err := os.ReadFile(termy.path)
	if err != nil {
		return failed(termy.Name(), "read config", err)
	}
	updated := replaceSetting(string(content), "theme", "hued")
	updated = replaceSetting(updated, "theme_mode", "manual")
	updated, err = replaceColorSection(updated, colors)
	if err != nil {
		return failed(termy.Name(), "update colors", err)
	}
	themeContent, err := json.MarshalIndent(colors, "", "  ")
	if err != nil {
		return failed(termy.Name(), "encode theme", err)
	}
	themePath := filepath.Join(termy.configDir, "termy", "themes", "hued.json")
	if err := files.WriteAtomic(themePath, append(themeContent, '\n'), 0o644); err != nil {
		return failed(termy.Name(), "write theme", err)
	}
	if err := files.WriteAtomic(termy.path, []byte(updated), fileMode(termy.path)); err != nil {
		return failed(termy.Name(), "write config", err)
	}
	return applied(termy.Name(), termy.path+"; file watcher reloads live")
}

func termyColors(theme domain.Theme) map[string]string {
	p := theme.Palette.Resolved(theme.Appearance)
	return map[string]string{
		"foreground": p.Text, "background": p.PanelBG, "cursor": p.Text,
		"black": p.ActiveSpaceBG, "red": p.Red, "green": p.Green, "yellow": p.Yellow,
		"blue": p.Blue, "magenta": p.Mauve, "cyan": p.Teal, "white": p.Text,
		"bright_black": p.Surface0, "bright_red": p.Red, "bright_green": p.Green,
		"bright_yellow": p.Yellow, "bright_blue": p.Blue, "bright_magenta": p.Mauve,
		"bright_cyan": p.Teal, "bright_white": p.Subtext0,
	}
}

var termyColorOrder = []string{
	"foreground", "background", "cursor", "black", "red", "green", "yellow", "blue", "magenta",
	"cyan", "white", "bright_black", "bright_red", "bright_green", "bright_yellow", "bright_blue",
	"bright_magenta", "bright_cyan", "bright_white",
}

func replaceColorSection(content string, colors map[string]string) (string, error) {
	lines := strings.Split(strings.TrimSuffix(content, "\n"), "\n")
	header := -1
	for index, line := range lines {
		if strings.TrimSpace(line) == "[colors]" {
			if header != -1 {
				return "", fmt.Errorf("multiple [colors] sections")
			}
			header = index
		}
	}
	if header == -1 {
		lines = append(lines, "", "[colors]")
		header = len(lines) - 1
	}
	end := len(lines)
	for index := header + 1; index < len(lines); index++ {
		trimmed := strings.TrimSpace(lines[index])
		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			end = index
			break
		}
	}
	found := make(map[string]bool)
	setting := regexp.MustCompile(`^\s*([A-Za-z_]+)\s*=`)
	for index := header + 1; index < end; index++ {
		match := setting.FindStringSubmatch(lines[index])
		if len(match) != 2 {
			continue
		}
		if value, ok := colors[match[1]]; ok {
			lines[index] = match[1] + " = " + value
			found[match[1]] = true
		}
	}
	missing := make([]string, 0)
	for _, key := range termyColorOrder {
		if !found[key] {
			missing = append(missing, key+" = "+colors[key])
		}
	}
	lines = append(lines[:end], append(missing, lines[end:]...)...)
	return strings.Join(lines, "\n") + "\n", nil
}
