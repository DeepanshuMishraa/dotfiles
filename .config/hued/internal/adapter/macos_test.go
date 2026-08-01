package adapter

import (
	"testing"
)

func TestNearestAppleHighlight(t *testing.T) {
	for value, expected := range map[string]string{
		"#89b4fa": "blue",
		"#cba6f7": "purple",
		"#f38ba8": "red",
		"#a6e3a1": "green",
		"#d0d0d0": "silver",
	} {
		actual, err := nearestAppleHighlight(value)
		if err != nil {
			t.Fatal(err)
		}
		if actual != expected {
			t.Fatalf("nearestAppleHighlight(%q) = %q, want %q", value, actual, expected)
		}
	}
}
