package domain

import "testing"

func TestThemeValidationRejectsMissingAppearance(t *testing.T) {
	theme := validTheme()
	theme.Appearance = ""
	if err := theme.Validate(); err == nil {
		t.Fatal("expected missing appearance to fail validation")
	}
}

func TestThemeValidationRejectsMalformedColor(t *testing.T) {
	theme := validTheme()
	theme.Palette.Accent = "purple"
	if err := theme.Validate(); err == nil {
		t.Fatal("expected malformed color to fail validation")
	}
}

func validTheme() Theme {
	palette := Palette{
		Accent: "#111111", PanelBG: "#111111", Surface0: "#111111", ActiveSpaceBG: "#111111",
		Surface1: "#111111", SurfaceDim: "#111111", Separator: "#111111", Overlay0: "#111111",
		Overlay1: "#111111", Text: "#111111", Subtext0: "#111111", Mauve: "#111111",
		Green: "#111111", Yellow: "#111111", Red: "#111111", Blue: "#111111",
		Teal: "#111111", Peach: "#111111",
	}
	return Theme{Name: "test", Appearance: AppearanceDark, Palette: palette}
}
