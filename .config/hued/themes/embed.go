package themes

import "embed"

// Bundled contains the read-only theme manifests shipped with Hued.
//
//go:embed bundled/*.json
var Bundled embed.FS
