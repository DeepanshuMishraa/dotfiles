package adapter

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"time"

	"github.com/dipxsy/hued/internal/domain"
	"github.com/dipxsy/hued/internal/files"
)

type BrowserTheme struct {
	Revision   int64             `json:"revision"`
	Name       string            `json:"name"`
	Appearance domain.Appearance `json:"appearance"`
	Palette    domain.Palette    `json:"palette"`
}

type Browser struct {
	stateDir string
}

func NewBrowser(stateDir string) *Browser {
	return &Browser{stateDir: stateDir}
}

func (browser *Browser) Name() string { return "browser" }
func (browser *Browser) Detect() bool { return true }
func (browser *Browser) Plan(theme domain.Theme) Action {
	return Action{Adapter: browser.Name(), Detail: filepath.Join(browser.stateDir, "browser-theme.json")}
}
func (browser *Browser) Apply(theme domain.Theme) domain.Result {
	value := BrowserTheme{Revision: time.Now().UnixNano(), Name: theme.Name, Appearance: theme.Appearance, Palette: theme.Palette.Resolved(theme.Appearance)}
	content, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return domain.Result{Adapter: browser.Name(), Status: domain.ResultFailed, Detail: fmt.Sprintf("encode browser theme: %v", err)}
	}
	content = append(content, '\n')
	path := filepath.Join(browser.stateDir, "browser-theme.json")
	if err := files.WriteAtomic(path, content, 0o644); err != nil {
		return domain.Result{Adapter: browser.Name(), Status: domain.ResultFailed, Detail: err.Error()}
	}
	return domain.Result{Adapter: browser.Name(), Status: domain.ResultApplied, Detail: path}
}
