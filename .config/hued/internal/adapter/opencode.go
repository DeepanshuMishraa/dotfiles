package adapter

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/dipxsy/hued/internal/domain"
	"github.com/dipxsy/hued/internal/files"
)

type OpenCode struct {
	configDir string
	settings  string
}

func NewOpenCode(configDir string) *OpenCode {
	return &OpenCode{configDir: configDir, settings: filepath.Join(configDir, "opencode", "tui.json")}
}

func (opencode *OpenCode) Name() string { return "opencode" }
func (opencode *OpenCode) Detect() bool { _, err := os.Stat(opencode.settings); return err == nil }
func (opencode *OpenCode) Plan(_ domain.Theme) Action {
	return Action{Adapter: opencode.Name(), Detail: filepath.Join(opencode.configDir, "opencode", "themes", "hued.json") + " + live SIGUSR2 reload"}
}
func (opencode *OpenCode) Apply(theme domain.Theme) domain.Result {
	p := theme.Palette.Resolved(theme.Appearance)
	values := map[string]string{
		"primary": p.Accent, "secondary": p.Mauve, "accent": p.Accent, "error": p.Red,
		"warning": p.Yellow, "success": p.Green, "info": p.Teal, "text": p.Text,
		"textMuted": p.Overlay0, "selectedListItemText": p.PanelBG, "background": p.PanelBG,
		"backgroundPanel": p.SurfaceDim, "backgroundElement": p.Surface0, "backgroundMenu": p.Surface0,
		"border": p.Separator, "borderActive": p.Accent, "borderSubtle": p.Surface0,
		"diffAdded": p.Green, "diffRemoved": p.Red, "diffContext": p.Overlay0,
		"markdownText": p.Text, "markdownHeading": p.Accent, "markdownLink": p.Blue,
		"markdownCode": p.Green, "syntaxComment": p.Overlay0, "syntaxKeyword": p.Mauve,
		"syntaxFunction": p.Blue, "syntaxVariable": p.Text, "syntaxString": p.Green,
		"syntaxNumber": p.Peach, "syntaxType": p.Teal, "syntaxOperator": p.Teal,
		"syntaxPunctuation": p.Text, "thinkingOpacity": "0.6",
	}
	content, err := json.MarshalIndent(struct {
		Theme map[string]string `json:"theme"`
	}{Theme: values}, "", "  ")
	if err != nil {
		return failed(opencode.Name(), "encode theme", err)
	}
	themePath := filepath.Join(opencode.configDir, "opencode", "themes", "hued.json")
	if err := files.WriteAtomic(themePath, append(content, '\n'), 0o644); err != nil {
		return failed(opencode.Name(), "write theme", err)
	}
	if err := setJSONField(opencode.settings, "theme", rawJSON("hued")); err != nil {
		return failed(opencode.Name(), "select theme", err)
	}
	if pkill, err := exec.LookPath("pkill"); err == nil {
		_ = exec.Command(pkill, "-SIGUSR2", "opencode").Run()
	}
	return applied(opencode.Name(), themePath+"; signaled running clients")
}
