package adapter

import (
	"strings"
	"testing"
)

func TestRenderObsidianOverridesThemeScopes(t *testing.T) {
	content := renderObsidian(testTheme())
	for _, expected := range []string{
		"body, body.theme-dark, body.theme-light {",
		"--background-primary: #191724 !important;",
		"--text-normal: #e0def4 !important;",
	} {
		if !strings.Contains(content, expected) {
			t.Fatalf("renderObsidian() missing %q:\n%s", expected, content)
		}
	}
}
