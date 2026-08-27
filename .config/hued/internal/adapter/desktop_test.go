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
