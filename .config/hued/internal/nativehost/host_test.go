package nativehost

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"testing"
)

func TestRunSendsCurrentThemeUsingNativeMessagingFraming(t *testing.T) {
	path := filepath.Join(t.TempDir(), "browser-theme.json")
	if err := os.WriteFile(path, []byte(`{"revision":1,"name":"rose-pine"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	request := frame([]byte(`{"type":"get_theme"}`))
	var output bytes.Buffer
	if err := Run(path, bytes.NewReader(request), &output); err != nil {
		t.Fatalf("run native host: %v", err)
	}
	message, err := readFrame(&output)
	if err != nil {
		t.Fatalf("read native response: %v", err)
	}
	var envelope Envelope
	if err := json.Unmarshal(message, &envelope); err != nil {
		t.Fatalf("decode native response: %v", err)
	}
	if envelope.Type != "theme" || !bytes.Contains(envelope.Theme, []byte("rose-pine")) {
		t.Fatalf("unexpected native response: %s", message)
	}
}

func frame(content []byte) []byte {
	header := make([]byte, 4)
	binary.LittleEndian.PutUint32(header, uint32(len(content)))
	return append(header, content...)
}

func readFrame(input io.Reader) ([]byte, error) {
	header := make([]byte, 4)
	if _, err := io.ReadFull(input, header); err != nil {
		return nil, err
	}
	content := make([]byte, binary.LittleEndian.Uint32(header))
	_, err := io.ReadFull(input, content)
	return content, err
}
