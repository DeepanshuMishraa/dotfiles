package adapter

import (
	"encoding/json"
	"os"
	"path/filepath"

	"github.com/dipxsy/hued/internal/domain"
	"github.com/dipxsy/hued/internal/files"
)

type Pi struct {
	home     string
	settings string
}

type piTheme struct {
	Name   string            `json:"name"`
	Vars   map[string]string `json:"vars"`
	Colors map[string]string `json:"colors"`
	Export map[string]string `json:"export"`
}

func NewPi(home string) *Pi {
	return &Pi{home: home, settings: filepath.Join(home, ".pi", "agent", "settings.json")}
}

func (pi *Pi) Name() string { return "pi-agent" }
func (pi *Pi) Detect() bool { _, err := os.Stat(pi.settings); return err == nil }
func (pi *Pi) Plan(_ domain.Theme) Action {
	return Action{Adapter: pi.Name(), Detail: filepath.Join(pi.home, ".pi", "agent", "themes", "hued.json") + " + theme watcher reload"}
}
func (pi *Pi) Apply(theme domain.Theme) domain.Result {
	content, err := json.MarshalIndent(renderPi(theme), "", "  ")
	if err != nil {
		return failed(pi.Name(), "encode theme", err)
	}
	path := filepath.Join(pi.home, ".pi", "agent", "themes", "hued.json")
	if err := files.WriteAtomic(path, append(content, '\n'), 0o644); err != nil {
		return failed(pi.Name(), "write theme", err)
	}
	if err := setJSONField(pi.settings, "theme", rawJSON("hued")); err != nil {
		return failed(pi.Name(), "select theme", err)
	}
	return applied(pi.Name(), path+"; Pi theme watcher reloads live")
}

func renderPi(theme domain.Theme) piTheme {
	p := theme.Palette.Resolved(theme.Appearance)
	vars := map[string]string{
		"accent": p.Accent, "panel_bg": p.PanelBG, "surface0": p.Surface0,
		"active_space_bg": p.ActiveSpaceBG, "surface1": p.Surface1, "surface_dim": p.SurfaceDim,
		"separator": p.Separator, "overlay0": p.Overlay0, "overlay1": p.Overlay1,
		"text": p.Text, "subtext0": p.Subtext0, "mauve": p.Mauve, "green": p.Green,
		"yellow": p.Yellow, "red": p.Red, "blue": p.Blue, "teal": p.Teal, "peach": p.Peach,
		"surface2": p.Separator, "base": p.PanelBG, "mantle": p.ActiveSpaceBG,
		"crust": p.SurfaceDim, "subtext1": p.Overlay1, "overlay2": p.Overlay0,
		"rosewater": p.Text, "flamingo": p.Peach, "pink": p.Mauve, "maroon": p.Red,
		"sky": p.Blue, "sapphire": p.Teal, "lavender": p.Accent, "toolErrorBg": p.Surface1,
	}
	colors := map[string]string{
		"accent": "blue", "border": "surface0", "borderAccent": "surface1", "borderMuted": "surface2",
		"success": "green", "error": "red", "warning": "yellow", "muted": "subtext1", "dim": "overlay1",
		"text": "text", "thinkingText": "overlay2", "selectedBg": "surface1", "userMessageBg": "mantle",
		"userMessageText": "text", "customMessageBg": "crust", "customMessageText": "text",
		"customMessageLabel": "pink", "toolPendingBg": "base", "toolSuccessBg": "mantle",
		"toolErrorBg": "toolErrorBg", "toolTitle": "blue", "toolOutput": "subtext1", "mdHeading": "mauve",
		"mdLink": "blue", "mdLinkUrl": "sky", "mdCode": "green", "mdCodeBlock": "text",
		"mdCodeBlockBorder": "surface2", "mdQuote": "yellow", "mdQuoteBorder": "yellow", "mdHr": "subtext0",
		"mdListBullet": "blue", "toolDiffAdded": "green", "toolDiffRemoved": "red", "toolDiffContext": "overlay2",
		"syntaxComment": "overlay2", "syntaxKeyword": "mauve", "syntaxFunction": "blue", "syntaxVariable": "red",
		"syntaxString": "green", "syntaxNumber": "peach", "syntaxType": "yellow", "syntaxOperator": "sky",
		"syntaxPunctuation": "text", "thinkingOff": "surface2", "thinkingMinimal": "surface1",
		"thinkingLow": "blue", "thinkingMedium": "teal", "thinkingHigh": "mauve", "thinkingXhigh": "pink",
		"bashMode": "peach",
	}
	return piTheme{
		Name: "hued", Vars: vars, Colors: colors,
		Export: map[string]string{"pageBg": p.ActiveSpaceBG, "cardBg": p.PanelBG, "infoBg": p.Surface0},
	}
}
