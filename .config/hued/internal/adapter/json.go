package adapter

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"

	"github.com/dipxsy/hued/internal/files"
)

func setJSONField(path, key string, value json.RawMessage) error {
	content, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read %s: %w", path, err)
	}
	object := make(map[string]json.RawMessage)
	decoder := json.NewDecoder(bytes.NewReader(content))
	if err := decoder.Decode(&object); err != nil {
		return fmt.Errorf("parse %s: %w", path, err)
	}
	object[key] = value
	updated, err := json.MarshalIndent(object, "", "  ")
	if err != nil {
		return fmt.Errorf("encode %s: %w", path, err)
	}
	mode := os.FileMode(0o644)
	if info, statErr := os.Stat(path); statErr == nil {
		mode = info.Mode().Perm()
	}
	return files.WriteAtomic(path, append(updated, '\n'), mode)
}

func rawJSON(value string) json.RawMessage {
	content, _ := json.Marshal(value)
	return json.RawMessage(content)
}
