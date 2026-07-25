function claudex -d "Run Claude Code through the local CLI proxy"
    env -u ANTHROPIC_API_KEY \
        ANTHROPIC_BASE_URL=http://127.0.0.1:8317 \
        ANTHROPIC_AUTH_TOKEN=claudex-local \
        CLAUDE_CODE_SUBAGENT_MODEL=gpt-5.6-sol \
        CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1 \
        CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3 \
        ENABLE_TOOL_SEARCH=false \
        claude --model gpt-5.6-sol $argv
end
