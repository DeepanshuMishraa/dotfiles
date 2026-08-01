package adapter

import (
	"fmt"
	"os"

	"github.com/dipxsy/hued/internal/domain"
)

func applied(name, detail string) domain.Result {
	return domain.Result{Adapter: name, Status: domain.ResultApplied, Detail: detail}
}

func failed(name, operation string, err error) domain.Result {
	return domain.Result{Adapter: name, Status: domain.ResultFailed, Detail: fmt.Sprintf("%s: %v", operation, err)}
}

func fileMode(path string) os.FileMode {
	if info, err := os.Stat(path); err == nil {
		return info.Mode().Perm()
	}
	return 0o644
}
