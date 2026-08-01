package adapter

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/dipxsy/hued/internal/domain"
)

type Raycast struct{}

func NewRaycast() *Raycast            { return &Raycast{} }
func (raycast *Raycast) Name() string { return "raycast" }
func (raycast *Raycast) Detect() bool {
	_, err := os.Stat("/Applications/Raycast.app")
	return err == nil
}
func (raycast *Raycast) Plan(_ domain.Theme) Action {
	return Action{Adapter: raycast.Name(), Detail: "follow Hued's macOS light/dark appearance; preserve private Raycast theme data"}
}
func (raycast *Raycast) Apply(_ domain.Theme) domain.Result {
	output, err := exec.Command("/usr/bin/defaults", "write", "com.raycast.macos", "raycastShouldFollowSystemAppearance", "-bool", "true").CombinedOutput()
	if err != nil {
		return failed(raycast.Name(), "enable Raycast system appearance", fmt.Errorf("%v: %s", err, output))
	}
	return applied(raycast.Name(), "Raycast follows Hued's system appearance; exact palettes require Raycast Theme Studio")
}
