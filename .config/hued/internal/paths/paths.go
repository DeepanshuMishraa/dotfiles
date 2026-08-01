package paths

import (
	"fmt"
	"os"
	"path/filepath"
)

type Paths struct {
	ConfigDir string
	ThemeDir  string
	StateDir  string
	CacheDir  string
}

func Resolve() (Paths, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return Paths{}, fmt.Errorf("resolve home directory: %w", err)
	}
	configHome := envOr("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	stateHome := envOr("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	cacheHome := envOr("XDG_CACHE_HOME", filepath.Join(home, ".cache"))
	configDir := filepath.Join(configHome, "hued")
	return Paths{
		ConfigDir: configDir,
		ThemeDir:  filepath.Join(configDir, "themes"),
		StateDir:  filepath.Join(stateHome, "hued"),
		CacheDir:  filepath.Join(cacheHome, "hued"),
	}, nil
}

func envOr(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}
