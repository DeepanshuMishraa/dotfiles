package adapter

import (
	"encoding/json"
	"os"
	"path/filepath"

	"github.com/dipxsy/hued/internal/domain"
	"github.com/dipxsy/hued/internal/files"
)

type Zed struct {
	configDir string
	settings  string
}

type zedSyntaxStyle struct {
	Color     string `json:"color"`
	FontStyle string `json:"font_style,omitempty"`
}

type zedVariant struct {
	Name       string                     `json:"name"`
	Appearance string                     `json:"appearance"`
	Style      map[string]json.RawMessage `json:"style"`
}

type zedTheme struct {
	Name   string       `json:"name"`
	Author string       `json:"author"`
	Themes []zedVariant `json:"themes"`
}

func NewZed(configDir string) *Zed {
	return &Zed{configDir: configDir, settings: filepath.Join(configDir, "zed", "settings.json")}
}

func (zed *Zed) Name() string { return "zed" }
func (zed *Zed) Detect() bool { _, err := os.Stat(zed.settings); return err == nil }
func (zed *Zed) Plan(_ domain.Theme) Action {
	return Action{Adapter: zed.Name(), Detail: filepath.Join(zed.configDir, "zed", "themes", "hued.json") + " + settings watcher reload"}
}
func (zed *Zed) Apply(theme domain.Theme) domain.Result {
	content, err := json.MarshalIndent(renderZed(theme), "", "  ")
	if err != nil {
		return failed(zed.Name(), "encode theme", err)
	}
	path := filepath.Join(zed.configDir, "zed", "themes", "hued.json")
	if err := files.WriteAtomic(path, append(content, '\n'), 0o644); err != nil {
		return failed(zed.Name(), "write theme", err)
	}
	selection := json.RawMessage(`{"mode":"system","light":"hued light","dark":"hued dark"}`)
	if err := setJSONField(zed.settings, "theme", selection); err != nil {
		return failed(zed.Name(), "select theme", err)
	}
	return applied(zed.Name(), path+"; Zed reloads watched files live")
}

func renderZed(theme domain.Theme) zedTheme {
	p := theme.Palette.Resolved(theme.Appearance)
	values := map[string]string{
		"background": p.PanelBG, "foreground": p.Text, "text": p.Text, "text.muted": p.Subtext0,
		"text.accent": p.Accent, "border": p.Separator, "border.variant": p.Surface0,
		"border.selected": p.Accent, "surface.background": p.Surface0,
		"elevated_surface.background": p.Surface1, "element.background": p.Surface1,
		"element.hover": p.Surface1, "element.selected": p.Surface0, "panel.background": p.ActiveSpaceBG,
		"tab_bar.background": p.SurfaceDim, "tab.active_background": p.Surface0,
		"tab.inactive_background": p.SurfaceDim, "title_bar.background": p.SurfaceDim,
		"status_bar.background": p.ActiveSpaceBG, "editor.background": p.PanelBG,
		"editor.foreground": p.Text, "editor.active_line.background": p.Surface0,
		"editor.line_number": p.Overlay0, "editor.active_line_number": p.Overlay1,
		"editor.gutter.background": p.PanelBG, "editor.indent_guide": p.Surface0,
		"pane.focused_border": p.Accent, "scrollbar.track.background": p.PanelBG,
		"scrollbar.thumb.background": p.Surface0, "search.match_background": p.Surface1,
		"error": p.Red, "warning": p.Yellow, "info": p.Blue, "hint": p.Teal,
		"success": p.Green, "conflict": p.Peach, "created": p.Green, "deleted": p.Red,
		"modified": p.Yellow, "terminal.background": p.PanelBG, "terminal.foreground": p.Text,
		"terminal.ansi.black": p.SurfaceDim, "terminal.ansi.red": p.Red,
		"terminal.ansi.green": p.Green, "terminal.ansi.yellow": p.Yellow,
		"terminal.ansi.blue": p.Blue, "terminal.ansi.magenta": p.Mauve,
		"terminal.ansi.cyan": p.Teal, "terminal.ansi.white": p.Text,
		"terminal.ansi.bright_black": p.Overlay0, "terminal.ansi.bright_white": p.Text,
	}
	style := make(map[string]json.RawMessage, len(values)+1)
	for key, value := range values {
		style[key] = rawJSON(value)
	}
	syntax, _ := json.Marshal(map[string]zedSyntaxStyle{
		"comment": {Color: p.Overlay0, FontStyle: "italic"}, "string": {Color: p.Green},
		"number": {Color: p.Peach}, "function": {Color: p.Blue}, "type": {Color: p.Teal},
		"keyword": {Color: p.Mauve, FontStyle: "italic"}, "operator": {Color: p.Teal},
		"variable": {Color: p.Text}, "punctuation": {Color: p.Text},
	})
	style["syntax"] = json.RawMessage(syntax)
	return zedTheme{
		Name: "hued", Author: "Hued",
		Themes: []zedVariant{{Name: "hued dark", Appearance: "dark", Style: style}, {Name: "hued light", Appearance: "light", Style: style}},
	}
}
