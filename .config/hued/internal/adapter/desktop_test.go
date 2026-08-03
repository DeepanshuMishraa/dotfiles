package adapter

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/dipxsy/hued/internal/domain"
)

func TestSketchyBarApplyWritesSemanticPalette(t *testing.T) {
	configDir := t.TempDir()
	configPath := filepath.Join(configDir, "sketchybar", "sketchybarrc")
	if err := os.MkdirAll(filepath.Dir(configPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(configPath, []byte("#!/usr/bin/env bash\n"), 0o755); err != nil {
		t.Fatal(err)
	}

	target := NewSketchyBar(configDir)
	result := target.Apply(testTheme())
	if result.Status != domain.ResultApplied {
		t.Fatalf("expected applied, got %#v", result)
	}
	content, err := os.ReadFile(filepath.Join(configDir, "sketchybar", "colors.sh"))
	if err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{
		`BG_BASE="0x191724"`,
		`BG_SURFACE="0x1f1d2e"`,
		`ACTIVE_SPACE_BG="0x191724"`,
		`FG_PRIMARY="0xe0def4"`,
		`FG_SECONDARY="0xc8c5dc"`,
		`FG_DIM="0x6e6a86"`,
		`ACCENT="0xc4a7e7"`,
		`GREEN="0x31748f"`,
		`YELLOW="0xf6c177"`,
		`RED="0xeb6f92"`,
	} {
		if !strings.Contains(string(content), expected) {
			t.Fatalf("generated palette is missing %q:\n%s", expected, content)
		}
	}
}

func TestJankyBordersApplyWritesExecutableThemeScript(t *testing.T) {
	configDir := t.TempDir()
	configPath := filepath.Join(configDir, "aerospace", "aerospace.toml")
	if err := os.MkdirAll(filepath.Dir(configPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(configPath, []byte("config-version = 2\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	target := NewJankyBorders(configDir)
	result := target.Apply(testTheme())
	if result.Status != domain.ResultApplied {
		t.Fatalf("expected applied, got %#v", result)
	}
	path := filepath.Join(configDir, "aerospace", "borders.sh")
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{"active_color=0xffc4a7e7", "inactive_color=0xff26233a", "width=5.0"} {
		if !strings.Contains(string(content), expected) {
			t.Fatalf("generated border script is missing %q:\n%s", expected, content)
		}
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o755 {
		t.Fatalf("border script mode = %o, want 755", info.Mode().Perm())
	}
}
