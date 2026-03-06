#!/bin/bash
# Claude Code SessionStart hook: save current tmux pane info
# Uses tmux display-message which detects the pane from the controlling TTY

TMUX_CMD="/opt/homebrew/bin/tmux"

# Read session_id from stdin JSON
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown'))" 2>/dev/null || echo "unknown")

PANE_INFO_FILE="/tmp/claude-tmux-pane-${SESSION_ID}"

# Get current pane ID via tmux (works even without $TMUX env var)
PANE_ID=$($TMUX_CMD display-message -p '#{pane_id}' 2>/dev/null)

if [ -n "$PANE_ID" ]; then
  echo "$PANE_ID" > "$PANE_INFO_FILE"
fi

exit 0
