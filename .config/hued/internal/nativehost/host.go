package nativehost

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"sync"
	"time"
)

const maximumMessageBytes = 1024 * 1024

type Envelope struct {
	Type  string          `json:"type"`
	Theme json.RawMessage `json:"theme,omitempty"`
	Error string          `json:"error,omitempty"`
}

type writer struct {
	output io.Writer
	mu     sync.Mutex
}

func Run(themePath string, input io.Reader, output io.Writer) error {
	messages := &writer{output: output}
	lastModification := time.Time{}
	if info, err := os.Stat(themePath); err == nil {
		lastModification = info.ModTime()
	}
	if err := sendTheme(messages, themePath); err != nil {
		if sendErr := messages.write(Envelope{Type: "error", Error: err.Error()}); sendErr != nil {
			return sendErr
		}
	}

	done := make(chan error, 1)
	go func() {
		for {
			if _, err := readMessage(input); err != nil {
				done <- err
				return
			}
			if err := sendTheme(messages, themePath); err != nil {
				if writeErr := messages.write(Envelope{Type: "error", Error: err.Error()}); writeErr != nil {
					done <- writeErr
					return
				}
			}
		}
	}()

	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case err := <-done:
			if err == io.EOF || err == io.ErrUnexpectedEOF {
				return nil
			}
			return err
		case <-ticker.C:
			info, err := os.Stat(themePath)
			if err != nil || !info.ModTime().After(lastModification) {
				continue
			}
			lastModification = info.ModTime()
			if err := sendTheme(messages, themePath); err != nil {
				if writeErr := messages.write(Envelope{Type: "error", Error: err.Error()}); writeErr != nil {
					return writeErr
				}
			}
		}
	}
}

func sendTheme(messages *writer, path string) error {
	content, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read active browser theme: %w", err)
	}
	if !json.Valid(content) {
		return fmt.Errorf("active browser theme is not valid JSON")
	}
	return messages.write(Envelope{Type: "theme", Theme: json.RawMessage(content)})
}

func (messages *writer) write(value Envelope) error {
	messages.mu.Lock()
	defer messages.mu.Unlock()
	content, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("encode native message: %w", err)
	}
	if len(content) > maximumMessageBytes {
		return fmt.Errorf("native message exceeds %d bytes", maximumMessageBytes)
	}
	header := make([]byte, 4)
	binary.LittleEndian.PutUint32(header, uint32(len(content)))
	if _, err := messages.output.Write(header); err != nil {
		return fmt.Errorf("write native message header: %w", err)
	}
	if _, err := messages.output.Write(content); err != nil {
		return fmt.Errorf("write native message body: %w", err)
	}
	return nil
}

func readMessage(input io.Reader) (json.RawMessage, error) {
	header := make([]byte, 4)
	if _, err := io.ReadFull(input, header); err != nil {
		return nil, err
	}
	length := binary.LittleEndian.Uint32(header)
	if length == 0 || length > maximumMessageBytes {
		return nil, fmt.Errorf("invalid native message length %d", length)
	}
	content := make([]byte, length)
	if _, err := io.ReadFull(input, content); err != nil {
		return nil, err
	}
	if !json.Valid(content) {
		return nil, fmt.Errorf("native request is not valid JSON")
	}
	return json.RawMessage(content), nil
}
