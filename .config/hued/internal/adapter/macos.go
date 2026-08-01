package adapter

import (
	"fmt"
	"os/exec"
	"runtime"
	"strconv"

	"github.com/dipxsy/hued/internal/domain"
)

type MacOS struct{}

func NewMacOS() *MacOS            { return &MacOS{} }
func (macos *MacOS) Name() string { return "macos" }
func (macos *MacOS) Detect() bool { return runtime.GOOS == "darwin" }
func (macos *MacOS) Plan(theme domain.Theme) Action {
	return Action{Adapter: macos.Name(), Detail: "set appearance and nearest supported highlight color live; preserve wallpaper"}
}
func (macos *MacOS) Apply(theme domain.Theme) domain.Result {
	palette := theme.Palette.Resolved(theme.Appearance)
	highlight, err := nearestAppleHighlight(palette.Accent)
	if err != nil {
		return failed(macos.Name(), "parse macOS accent color", err)
	}

	dark := theme.Appearance == domain.AppearanceDark
	appearanceScript := fmt.Sprintf(`tell application "System Events"
	tell appearance preferences
		set dark mode to %t
		set highlight color to %s
	end tell
end tell`, dark, highlight)
	if output, commandErr := exec.Command("/usr/bin/osascript", "-e", appearanceScript).CombinedOutput(); commandErr != nil {
		return domain.Result{Adapter: macos.Name(), Status: domain.ResultFailed, Detail: fmt.Sprintf("set macOS appearance and highlight color: %v: %s", commandErr, output)}
	}

	return applied(macos.Name(), "appearance and "+highlight+" highlight updated live; wallpaper preserved")
}

func nearestAppleHighlight(value string) (string, error) {
	parsed, err := strconv.ParseUint(value[1:], 16, 24)
	if err != nil {
		return "", fmt.Errorf("parse %q: %w", value, err)
	}
	r := float64((parsed >> 16) & 0xff)
	g := float64((parsed >> 8) & 0xff)
	b := float64(parsed & 0xff)
	maximum := max(r, g, b)
	minimum := min(r, g, b)
	if maximum == 0 || (maximum-minimum)/maximum < 0.15 {
		if maximum > 180 {
			return "silver", nil
		}
		return "graphite", nil
	}
	delta := maximum - minimum
	var hue float64
	switch maximum {
	case r:
		hue = 60 * (g - b) / delta
	case g:
		hue = 120 + 60*(b-r)/delta
	default:
		hue = 240 + 60*(r-g)/delta
	}
	if hue < 0 {
		hue += 360
	}
	choices := []struct {
		name string
		hue  float64
	}{{"red", 0}, {"orange", 35}, {"gold", 50}, {"green", 120}, {"blue", 215}, {"purple", 275}}
	best := choices[0]
	bestDistance := 360.0
	for _, choice := range choices {
		distance := min(abs(hue-choice.hue), 360-abs(hue-choice.hue))
		if distance < bestDistance {
			best = choice
			bestDistance = distance
		}
	}
	return best.name, nil
}

func abs(value float64) float64 {
	if value < 0 {
		return -value
	}
	return value
}
