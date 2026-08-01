package repository

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/dipxsy/hued/internal/domain"
)

func TestSeedAndLoadBundledThemes(t *testing.T) {
	root := filepath.Join(t.TempDir(), "themes")
	themes := NewThemes(root)
	if err := themes.Seed(); err != nil {
		t.Fatalf("seed themes: %v", err)
	}
	available, err := themes.List()
	if err != nil {
		t.Fatalf("list themes: %v", err)
	}
	if len(available) != 20 {
		t.Fatalf("expected 20 themes, got %d", len(available))
	}
	latte, err := themes.Load("catppuccin latte")
	if err != nil {
		t.Fatalf("load alias-normalized name: %v", err)
	}
	if latte.Appearance != domain.AppearanceLight {
		t.Fatalf("expected latte to be light, got %q", latte.Appearance)
	}
}

func TestCustomThemeOverridesBundledTheme(t *testing.T) {
	root := filepath.Join(t.TempDir(), "themes")
	themes := NewThemes(root)
	if err := themes.Seed(); err != nil {
		t.Fatalf("seed themes: %v", err)
	}
	bundled, err := os.ReadFile(filepath.Join(root, "bundled", "rose-pine.json"))
	if err != nil {
		t.Fatalf("read bundled theme: %v", err)
	}
	var customTheme domain.Theme
	if err := json.Unmarshal(bundled, &customTheme); err != nil {
		t.Fatalf("decode bundled theme: %v", err)
	}
	customTheme.Palette.Accent = "#123456"
	custom, err := json.Marshal(customTheme)
	if err != nil {
		t.Fatalf("encode custom theme: %v", err)
	}
	customPath := filepath.Join(root, "custom", "rose-pine.json")
	if err := os.WriteFile(customPath, custom, 0o644); err != nil {
		t.Fatalf("write custom theme: %v", err)
	}
	loaded, err := themes.Load("rose-pine")
	if err != nil {
		t.Fatalf("load overridden theme: %v", err)
	}
	if loaded.Palette.Accent != "#123456" {
		t.Fatalf("expected custom accent, got %s", loaded.Palette.Accent)
	}
}
