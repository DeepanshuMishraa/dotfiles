package domain

type ResultStatus string

const (
	ResultApplied     ResultStatus = "applied"
	ResultUnchanged   ResultStatus = "unchanged"
	ResultDeferred    ResultStatus = "deferred"
	ResultManualSetup ResultStatus = "manual_setup_required"
	ResultUnsupported ResultStatus = "unsupported"
	ResultFailed      ResultStatus = "failed"
)

type Result struct {
	Adapter string       `json:"adapter"`
	Status  ResultStatus `json:"status"`
	Detail  string       `json:"detail"`
}
