package orchestrator

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/dipxsy/hued/internal/adapter"
	"github.com/dipxsy/hued/internal/domain"
	"github.com/dipxsy/hued/internal/state"
)

type Orchestrator struct {
	stateDir string
	adapters []adapter.Adapter
}

func (orchestrator Orchestrator) Only(value string) (Orchestrator, error) {
	if strings.TrimSpace(value) == "" {
		return orchestrator, nil
	}
	requested := make(map[string]bool)
	for _, name := range strings.Split(value, ",") {
		requested[strings.TrimSpace(name)] = true
	}
	selected := make([]adapter.Adapter, 0, len(requested))
	known := make(map[string]bool)
	for _, target := range orchestrator.adapters {
		known[target.Name()] = true
		if requested[target.Name()] {
			selected = append(selected, target)
		}
	}
	var unknown []string
	for name := range requested {
		if !known[name] {
			unknown = append(unknown, name)
		}
	}
	if len(unknown) > 0 {
		sort.Strings(unknown)
		return Orchestrator{}, fmt.Errorf("unknown adapters: %s", strings.Join(unknown, ", "))
	}
	return Orchestrator{stateDir: orchestrator.stateDir, adapters: selected}, nil
}

func New(stateDir string, adapters []adapter.Adapter) Orchestrator {
	return Orchestrator{stateDir: stateDir, adapters: adapters}
}

func (orchestrator Orchestrator) Plan(theme domain.Theme) []adapter.Action {
	var actions []adapter.Action
	for _, target := range orchestrator.adapters {
		if target.Detect() {
			actions = append(actions, target.Plan(theme))
		}
	}
	return actions
}

func (orchestrator Orchestrator) Apply(theme domain.Theme) ([]domain.Result, error) {
	release, err := orchestrator.lock()
	if err != nil {
		return nil, err
	}
	defer release()

	results := make([]domain.Result, 0, len(orchestrator.adapters))
	for _, target := range orchestrator.adapters {
		if !target.Detect() {
			results = append(results, domain.Result{Adapter: target.Name(), Status: domain.ResultUnsupported, Detail: "not detected"})
			continue
		}
		results = append(results, target.Apply(theme))
	}

	value := state.State{Revision: time.Now().UnixNano(), Theme: theme.Name, AppliedAt: time.Now().UTC(), Results: results}
	if err := state.Write(orchestrator.stateDir, value); err != nil {
		return results, err
	}
	for index, target := range orchestrator.adapters {
		postCommit, ok := target.(adapter.PostCommit)
		if !ok || results[index].Status != domain.ResultApplied {
			continue
		}
		if err := postCommit.PostCommit(); err != nil {
			return results, fmt.Errorf("run %s live reload: %w", target.Name(), err)
		}
	}
	return results, nil
}

func (orchestrator Orchestrator) lock() (func(), error) {
	if err := os.MkdirAll(orchestrator.stateDir, 0o755); err != nil {
		return nil, fmt.Errorf("create Hued state directory: %w", err)
	}
	path := filepath.Join(orchestrator.stateDir, "apply.lock")
	file, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		if os.IsExist(err) {
			return nil, fmt.Errorf("another Hued apply is active; if it crashed, remove %s", path)
		}
		return nil, fmt.Errorf("create apply lock: %w", err)
	}
	_ = file.Close()
	return func() { _ = os.Remove(path) }, nil
}
