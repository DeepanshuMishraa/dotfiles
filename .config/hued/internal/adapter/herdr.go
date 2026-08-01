package adapter

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/dipxsy/hued/internal/domain"
	"github.com/dipxsy/hued/internal/files"
)

type Herdr struct {
	path string
}

func NewHerdr(configDir string) *Herdr {
	return &Herdr{path: filepath.Join(configDir, "herdr", "config.toml")}
}

func (herdr *Herdr) Name() string { return "herdr" }
func (herdr *Herdr) Detect() bool { _, err := os.Stat(herdr.path); return err == nil }
func (herdr *Herdr) Plan(_ domain.Theme) Action {
	return Action{Adapter: herdr.Name(), Detail: herdr.path + " + live server reload"}
}
func (herdr *Herdr) Apply(theme domain.Theme) domain.Result {
	content, err := os.ReadFile(herdr.path)
	if err != nil {
		return failed(herdr.Name(), "read config", err)
	}
	name := theme.Name
	if theme.Targets.Herdr != nil && *theme.Targets.Herdr != "" {
		name = *theme.Targets.Herdr
	}
	updated := setTOMLSectionValue(string(content), "theme", "name", strconvQuote(name))
	if err := files.WriteAtomic(herdr.path, []byte(updated), fileMode(herdr.path)); err != nil {
		return failed(herdr.Name(), "write config", err)
	}
	if executable, err := exec.LookPath("herdr"); err == nil {
		if exec.Command("/usr/bin/pgrep", "-x", "herdr").Run() != nil {
			return applied(herdr.Name(), herdr.path+"; configuration persisted for the next launch")
		}
		if output, reloadErr := exec.Command(executable, "server", "reload-config").CombinedOutput(); reloadErr != nil {
			return failed(herdr.Name(), "config updated but live reload failed", fmt.Errorf("%v: %s", reloadErr, output))
		}
	}
	return applied(herdr.Name(), herdr.path+"; configuration persisted and reloaded live")
}

func setTOMLSectionValue(content, section, key, value string) string {
	sectionPattern := regexp.MustCompile(`(?m)^\s*\[` + regexp.QuoteMeta(section) + `\]\s*$`)
	location := sectionPattern.FindStringIndex(content)
	if location == nil {
		return strings.TrimRight(content, "\n") + "\n\n[" + section + "]\n" + key + " = " + value + "\n"
	}
	rest := content[location[1]:]
	nextSection := regexp.MustCompile(`(?m)^\s*\[[^]]+\]\s*$`).FindStringIndex(rest)
	end := len(content)
	if nextSection != nil {
		end = location[1] + nextSection[0]
	}
	body := content[location[1]:end]
	keyPattern := regexp.MustCompile(`(?m)^(\s*` + regexp.QuoteMeta(key) + `\s*=\s*).*$`)
	if keyPattern.MatchString(body) {
		body = keyPattern.ReplaceAllString(body, "${1}"+value)
	} else {
		body = "\n" + key + " = " + value + strings.TrimPrefix(body, "\n")
	}
	return content[:location[1]] + body + content[end:]
}

func strconvQuote(value string) string {
	return fmt.Sprintf("%q", value)
}
