FILE="$CLAUDE_TOOL_INPUT_FILE_PATH"
[[ "$FILE" != *.py ]] && exit 0

pyright "$FILE" --outputjson 2>/dev/null \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
errs = [e for e in d.get('generalDiagnostics', []) if e['severity'] == 'error']
for e in errs[:10]:
    line = e['range']['start']['line'] + 1
    print(f\"pyright: {e['file']}:{line}: {e['message']}\", file=sys.stderr)
sys.exit(1 if errs else 0)
"