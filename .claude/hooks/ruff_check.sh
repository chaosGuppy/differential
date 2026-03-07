FILE="$CLAUDE_TOOL_INPUT_FILE_PATH"
[[ "$FILE" != *.py ]] && exit 0

uv run ruff check --fix "$FILE" && uv run ruff format "$FILE"
