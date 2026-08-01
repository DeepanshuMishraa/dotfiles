package adapter

import (
	"strings"
	"testing"
)

func TestRenderSpotifyColors(t *testing.T) {
	content := renderSpotifyColorBody(testTheme())
	for _, expected := range []string{"text                 = e0def4", "main                 = 191724", "button               = c4a7e7"} {
		if !strings.Contains(content, expected) {
			t.Fatalf("renderSpotifyColorBody() missing %q:\n%s", expected, content)
		}
	}
}

func TestReplaceINISectionPreservesTheActiveTheme(t *testing.T) {
	before := "[rose-pine]\ntext = ffffff\n\n[latte]\ntext = 000000\n"
	first := replaceINISection(before, "hued", "text = 111111\n")
	second := replaceINISection(first, "hued", "text = 222222\n")
	for _, expected := range []string{"[rose-pine]\ntext = ffffff", "[latte]\ntext = 000000", "[hued]\ntext = 222222"} {
		if !strings.Contains(second, expected) {
			t.Fatalf("replaceINISection() missing %q:\n%s", expected, second)
		}
	}
	if strings.Contains(second, "text = 111111") || strings.Count(second, "[hued]") != 1 {
		t.Fatalf("replaceINISection() did not replace its owned section:\n%s", second)
	}
}
