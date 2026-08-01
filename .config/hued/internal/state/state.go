package state

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/dipxsy/hued/internal/domain"
	"github.com/dipxsy/hued/internal/files"
)

type State struct {
	Revision  int64           `json:"revision"`
	Theme     string          `json:"theme"`
	AppliedAt time.Time       `json:"applied_at"`
	Results   []domain.Result `json:"results"`
}

func Read(directory string) (State, error) {
	path := filepath.Join(directory, "state.json")
	content, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return State{}, nil
		}
		return State{}, fmt.Errorf("read Hued state: %w", err)
	}
	var value State
	if err := json.Unmarshal(content, &value); err != nil {
		return State{}, fmt.Errorf("parse Hued state: %w", err)
	}
	return value, nil
}

func Write(directory string, value State) error {
	content, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return fmt.Errorf("encode Hued state: %w", err)
	}
	content = append(content, '\n')
	return files.WriteAtomic(filepath.Join(directory, "state.json"), content, 0o644)
}
