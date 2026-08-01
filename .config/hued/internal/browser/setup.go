package browser

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"

	"github.com/dipxsy/hued/internal/files"
)

var extensionID = regexp.MustCompile(`^[a-p]{32}$`)

type hostManifest struct {
	Name           string   `json:"name"`
	Description    string   `json:"description"`
	Path           string   `json:"path"`
	Type           string   `json:"type"`
	AllowedOrigins []string `json:"allowed_origins"`
}

func Setup(home, _ string, browserName, id string) (string, error) {
	if !extensionID.MatchString(id) {
		return "", fmt.Errorf("extension ID must contain exactly 32 characters from a-p")
	}
	executable, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("resolve Hued executable: %w", err)
	}
	directory, err := nativeHostDirectory(home, browserName)
	if err != nil {
		return "", err
	}
	manifest := hostManifest{
		Name: "io.hued.bridge", Description: "Hued browser theme bridge",
		Path: executable, Type: "stdio", AllowedOrigins: []string{"chrome-extension://" + id + "/"},
	}
	content, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return "", fmt.Errorf("encode native host manifest: %w", err)
	}
	content = append(content, '\n')
	path := filepath.Join(directory, "io.hued.bridge.json")
	if err := files.WriteAtomic(path, content, 0o644); err != nil {
		return "", err
	}
	return path, nil
}

func nativeHostDirectory(home, browserName string) (string, error) {
	switch browserName {
	case "arc":
		// Arc's current macOS build uses Chromium's Google Chrome branding for
		// native-host discovery even though its profile lives under Arc/User Data.
		return filepath.Join(home, "Library", "Application Support", "Google", "Chrome", "NativeMessagingHosts"), nil
	case "chrome":
		return filepath.Join(home, "Library", "Application Support", "Google", "Chrome", "NativeMessagingHosts"), nil
	case "chromium":
		return filepath.Join(home, "Library", "Application Support", "Chromium", "NativeMessagingHosts"), nil
	default:
		return "", fmt.Errorf("unsupported browser %q; expected arc, chrome, or chromium", browserName)
	}
}
