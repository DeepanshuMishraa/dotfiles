package browser

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestSetupWritesArcNativeHostManifestForFixedExtension(t *testing.T) {
	home := t.TempDir()
	stateDir := filepath.Join(home, ".local", "state", "hued")
	path, err := Setup(home, stateDir, "arc", "abcdefghijklmnopabcdefghijklmnop")
	if err != nil {
		t.Fatalf("setup browser host: %v", err)
	}
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read native host manifest: %v", err)
	}
	var manifest hostManifest
	if err := json.Unmarshal(content, &manifest); err != nil {
		t.Fatalf("decode native host manifest: %v", err)
	}
	if manifest.Name != "io.hued.bridge" {
		t.Fatalf("unexpected host name %q", manifest.Name)
	}
	if manifest.AllowedOrigins[0] != "chrome-extension://abcdefghijklmnopabcdefghijklmnop/" {
		t.Fatalf("unexpected allowed origin %q", manifest.AllowedOrigins[0])
	}
	expectedDirectory := filepath.Join(home, "Library", "Application Support", "Google", "Chrome", "NativeMessagingHosts")
	if filepath.Dir(path) != expectedDirectory {
		t.Fatalf("Arc manifest directory = %q, want %q", filepath.Dir(path), expectedDirectory)
	}
	info, err := os.Stat(manifest.Path)
	if err != nil {
		t.Fatalf("inspect native host executable: %v", err)
	}
	if !info.Mode().IsRegular() || info.Mode().Perm()&0o111 == 0 {
		t.Fatalf("expected native host path to be an executable file, got %s", info.Mode())
	}
}

func TestSetupRejectsInvalidExtensionID(t *testing.T) {
	if _, err := Setup(t.TempDir(), t.TempDir(), "arc", "not-an-extension-id"); err == nil {
		t.Fatal("expected invalid extension ID to fail")
	}
}
