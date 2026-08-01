package adapter

import "github.com/dipxsy/hued/internal/domain"

type Action struct {
	Adapter string
	Detail  string
}

type Adapter interface {
	Name() string
	Detect() bool
	Plan(domain.Theme) Action
	Apply(domain.Theme) domain.Result
}

type PostCommit interface {
	PostCommit() error
}
