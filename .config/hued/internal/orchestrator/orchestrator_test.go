package orchestrator

import (
	"testing"

	"github.com/dipxsy/hued/internal/adapter"
	"github.com/dipxsy/hued/internal/domain"
)

type postCommitAdapter struct {
	status domain.ResultStatus
	posts  int
}

func (target *postCommitAdapter) Name() string                     { return "target" }
func (target *postCommitAdapter) Detect() bool                     { return true }
func (target *postCommitAdapter) Plan(domain.Theme) adapter.Action { return adapter.Action{} }
func (target *postCommitAdapter) Apply(domain.Theme) domain.Result {
	return domain.Result{Adapter: target.Name(), Status: target.status}
}
func (target *postCommitAdapter) PostCommit() error {
	target.posts++
	return nil
}

func TestApplyRunsPostCommitOnlyAfterSuccessfulApply(t *testing.T) {
	for _, test := range []struct {
		name     string
		status   domain.ResultStatus
		expected int
	}{
		{name: "applied", status: domain.ResultApplied, expected: 1},
		{name: "failed", status: domain.ResultFailed, expected: 0},
	} {
		t.Run(test.name, func(t *testing.T) {
			target := &postCommitAdapter{status: test.status}
			runner := New(t.TempDir(), []adapter.Adapter{target})
			if _, err := runner.Apply(domain.Theme{Name: "test"}); err != nil {
				t.Fatal(err)
			}
			if target.posts != test.expected {
				t.Fatalf("post commits = %d, want %d", target.posts, test.expected)
			}
		})
	}
}
