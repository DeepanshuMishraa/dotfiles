package adapter

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/dipxsy/hued/internal/domain"
)

func TestGhosttyApplyPreservesLiveReloadConfigurationPath(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	configDir := filepath.Join(root, "config")
	stateDir := filepath.Join(root, "state")
	xdgConfig := filepath.Join(configDir, "ghostty", "config")
	macConfig := filepath.Join(home, "Library", "Application Support", "com.mitchellh.ghostty", "config")
	for _, path := range []string{xdgConfig, macConfig} {
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(xdgConfig, []byte("font-size = 18\nbackground = #000000\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(macConfig, []byte("theme = old\nwindow-width = 117\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	ghostty := NewGhostty(home, configDir, stateDir)
	result := ghostty.Apply(testTheme())
	if result.Status != domain.ResultApplied {
		t.Fatalf("expected applied, got %#v", result)
	}
	generated := filepath.Join(configDir, "ghostty", "themes", "herdr-global")
	macContent, err := os.ReadFile(macConfig)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(macContent), "theme = "+generated) || !strings.Contains(string(macContent), "window-width = 117") {
		t.Fatalf("macOS config was not updated surgically:\n%s", macContent)
	}
	xdgContent, err := os.ReadFile(xdgConfig)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(xdgContent), "background = #191724") || !strings.Contains(string(xdgContent), "font-size = 18") {
		t.Fatalf("XDG config was not updated surgically:\n%s", xdgContent)
	}
	themeContent, err := os.ReadFile(generated)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(themeContent), "palette = 15=#c8c5dc") {
		t.Fatalf("generated theme is incomplete:\n%s", themeContent)
	}
}

func testTheme() domain.Theme {
	background := "#191724"
	return domain.Theme{
		Name: "rose-pine", Appearance: domain.AppearanceDark,
		Palette: domain.Palette{
			Accent: "#c4a7e7", PanelBG: background, Surface0: "#1f1d2e", ActiveSpaceBG: background,
			Surface1: "#26233a", SurfaceDim: background, Separator: "#1f1d2e", Overlay0: "#6e6a86",
			Overlay1: "#908caa", Text: "#e0def4", Subtext0: "#c8c5dc", Mauve: "#c4a7e7",
			Green: "#31748f", Yellow: "#f6c177", Red: "#eb6f92", Blue: "#31748f",
			Teal: "#9ccfd8", Peach: "#ea9a97",
		},
		Targets: domain.Targets{GhosttyBackground: &background},
	}
}
