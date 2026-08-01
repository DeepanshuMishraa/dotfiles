package adapter

import (
	"regexp"
	"strings"
)

func replaceSetting(content, key, value string) string {
	pattern := regexp.MustCompile(`(?m)^(\s*` + regexp.QuoteMeta(key) + `\s*=\s*).*$`)
	if pattern.MatchString(content) {
		return pattern.ReplaceAllString(content, "${1}"+value)
	}
	if content != "" && !strings.HasSuffix(content, "\n") {
		content += "\n"
	}
	return content + key + " = " + value + "\n"
}
