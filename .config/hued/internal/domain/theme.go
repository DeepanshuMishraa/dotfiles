package domain

import (
	"errors"
	"fmt"
	"regexp"
	"sort"
	"strings"
)

type Appearance string

const (
	AppearanceDark  Appearance = "dark"
	AppearanceLight Appearance = "light"
)

type Palette struct {
	Accent        string `json:"accent"`
	PanelBG       string `json:"panel_bg"`
	Surface0      string `json:"surface0"`
	ActiveSpaceBG string `json:"active_space_bg"`
	Surface1      string `json:"surface1"`
	SurfaceDim    string `json:"surface_dim"`
	Separator     string `json:"separator"`
	Overlay0      string `json:"overlay0"`
	Overlay1      string `json:"overlay1"`
	Text          string `json:"text"`
	Subtext0      string `json:"subtext0"`
	Mauve         string `json:"mauve"`
	Green         string `json:"green"`
	Yellow        string `json:"yellow"`
	Red           string `json:"red"`
	Blue          string `json:"blue"`
	Teal          string `json:"teal"`
	Peach         string `json:"peach"`
}

type Targets struct {
	Herdr             *string `json:"herdr"`
	Pi                *string `json:"pi"`
	Zed               *string `json:"zed"`
	TmuxFlavour       *string `json:"tmux_flavour"`
	GhosttyBackground *string `json:"ghostty_background"`
	OpenCode          *string `json:"opencode"`
	HackTUI           *string `json:"hacktui"`
}

type Theme struct {
	Name       string     `json:"name"`
	Appearance Appearance `json:"appearance"`
	Palette    Palette    `json:"palette"`
	Targets    Targets    `json:"targets"`
}

var hexColor = regexp.MustCompile(`^#[0-9a-fA-F]{6}$`)

func (theme Theme) Validate() error {
	var problems []string
	if strings.TrimSpace(theme.Name) == "" {
		problems = append(problems, "name is required")
	}
	if theme.Appearance != AppearanceDark && theme.Appearance != AppearanceLight {
		problems = append(problems, `appearance must be "dark" or "light"`)
	}
	colors := map[string]string{
		"accent": theme.Palette.Accent, "panel_bg": theme.Palette.PanelBG,
		"surface0": theme.Palette.Surface0, "active_space_bg": theme.Palette.ActiveSpaceBG,
		"surface1": theme.Palette.Surface1, "surface_dim": theme.Palette.SurfaceDim,
		"separator": theme.Palette.Separator, "overlay0": theme.Palette.Overlay0,
		"overlay1": theme.Palette.Overlay1, "text": theme.Palette.Text,
		"subtext0": theme.Palette.Subtext0, "mauve": theme.Palette.Mauve,
		"green": theme.Palette.Green, "yellow": theme.Palette.Yellow,
		"red": theme.Palette.Red, "blue": theme.Palette.Blue,
		"teal": theme.Palette.Teal, "peach": theme.Palette.Peach,
	}
	keys := make([]string, 0, len(colors))
	for key := range colors {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		if colors[key] != "default" && !hexColor.MatchString(colors[key]) {
			problems = append(problems, fmt.Sprintf("palette.%s must be a six-digit hex color", key))
		}
	}
	if len(problems) > 0 {
		return errors.New(strings.Join(problems, "; "))
	}
	return nil
}

func (palette Palette) Resolved(appearance Appearance) Palette {
	background := "#000000"
	foreground := "#ffffff"
	if appearance == AppearanceLight {
		background = "#ffffff"
		foreground = "#000000"
	}
	resolve := func(value, fallback string) string {
		if value == "default" {
			return fallback
		}
		return value
	}
	palette.PanelBG = resolve(palette.PanelBG, background)
	palette.Surface0 = resolve(palette.Surface0, background)
	palette.ActiveSpaceBG = resolve(palette.ActiveSpaceBG, background)
	palette.Surface1 = resolve(palette.Surface1, background)
	palette.SurfaceDim = resolve(palette.SurfaceDim, background)
	palette.Separator = resolve(palette.Separator, foreground)
	palette.Overlay0 = resolve(palette.Overlay0, foreground)
	palette.Overlay1 = resolve(palette.Overlay1, foreground)
	palette.Text = resolve(palette.Text, foreground)
	palette.Subtext0 = resolve(palette.Subtext0, foreground)
	palette.Accent = resolve(palette.Accent, foreground)
	palette.Mauve = resolve(palette.Mauve, foreground)
	palette.Green = resolve(palette.Green, foreground)
	palette.Yellow = resolve(palette.Yellow, foreground)
	palette.Red = resolve(palette.Red, foreground)
	palette.Blue = resolve(palette.Blue, foreground)
	palette.Teal = resolve(palette.Teal, foreground)
	palette.Peach = resolve(palette.Peach, foreground)
	return palette
}
