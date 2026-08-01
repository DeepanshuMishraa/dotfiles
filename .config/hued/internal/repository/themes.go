package repository

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/dipxsy/hued/internal/domain"
	"github.com/dipxsy/hued/internal/files"
	builtinthemes "github.com/dipxsy/hued/themes"
)

type Themes struct {
	root string
}

func NewThemes(root string) Themes {
	return Themes{root: root}
}

func (themes Themes) Seed() error {
	bundledDir := filepath.Join(themes.root, "bundled")
	if err := os.MkdirAll(bundledDir, 0o755); err != nil {
		return fmt.Errorf("create bundled themes directory: %w", err)
	}
	entries, err := fs.ReadDir(builtinthemes.Bundled, "bundled")
	if err != nil {
		return fmt.Errorf("read embedded themes: %w", err)
	}
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".json" {
			continue
		}
		target := filepath.Join(bundledDir, entry.Name())
		if _, err := os.Stat(target); err == nil {
			continue
		} else if !os.IsNotExist(err) {
			return fmt.Errorf("inspect bundled theme %s: %w", entry.Name(), err)
		}
		content, err := builtinthemes.Bundled.ReadFile(filepath.Join("bundled", entry.Name()))
		if err != nil {
			return fmt.Errorf("read embedded theme %s: %w", entry.Name(), err)
		}
		if err := files.WriteAtomic(target, content, 0o644); err != nil {
			return err
		}
	}
	if err := os.MkdirAll(filepath.Join(themes.root, "custom"), 0o755); err != nil {
		return fmt.Errorf("create custom themes directory: %w", err)
	}
	return nil
}

func (themes Themes) List() ([]domain.Theme, error) {
	byName := make(map[string]domain.Theme)
	for _, directory := range []string{"bundled", "custom"} {
		matches, err := filepath.Glob(filepath.Join(themes.root, directory, "*.json"))
		if err != nil {
			return nil, fmt.Errorf("list %s themes: %w", directory, err)
		}
		for _, path := range matches {
			theme, err := readTheme(path)
			if err != nil {
				return nil, err
			}
			byName[theme.Name] = theme
		}
	}
	names := make([]string, 0, len(byName))
	for name := range byName {
		names = append(names, name)
	}
	sort.Strings(names)
	result := make([]domain.Theme, 0, len(names))
	for _, name := range names {
		result = append(result, byName[name])
	}
	return result, nil
}

func (themes Themes) Load(name string) (domain.Theme, error) {
	normalized := normalizeName(name)
	available, err := themes.List()
	if err != nil {
		return domain.Theme{}, err
	}
	for _, theme := range available {
		if normalizeName(theme.Name) == normalized {
			return theme, nil
		}
	}
	return domain.Theme{}, fmt.Errorf("unknown theme %q; run `hued list`", name)
}

func readTheme(path string) (domain.Theme, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return domain.Theme{}, fmt.Errorf("read theme %s: %w", path, err)
	}
	var theme domain.Theme
	decoder := json.NewDecoder(strings.NewReader(string(content)))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&theme); err != nil {
		return domain.Theme{}, fmt.Errorf("parse theme %s: %w", path, err)
	}
	if err := theme.Validate(); err != nil {
		return domain.Theme{}, fmt.Errorf("validate theme %s: %w", path, err)
	}
	return theme, nil
}

func normalizeName(value string) string {
	return strings.ReplaceAll(strings.ReplaceAll(strings.ToLower(strings.TrimSpace(value)), "_", "-"), " ", "-")
}
