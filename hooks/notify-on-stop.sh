#!/bin/bash
# Claude Code Stop hook: send notification via ClaudeNotify.app
# Summarizes last_assistant_message for the notification body

TMUX_CMD="/opt/homebrew/bin/tmux"
NOTIFY_APP="$HOME/.claude/hooks/ClaudeNotify.app"

# Read JSON from stdin
INPUT=$(cat)

# Skip if this is a re-entry from stop_hook_active
STOP_HOOK_ACTIVE=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active',False))" 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "True" ]; then
  exit 0
fi

SESSION_ID=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','unknown'))" 2>/dev/null || echo "unknown")

# Read the saved tmux pane ID
PANE_INFO_FILE="/tmp/claude-tmux-pane-${SESSION_ID}"
TMUX_PANE_ID=""
if [ -f "$PANE_INFO_FILE" ]; then
  TMUX_PANE_ID=$(cat "$PANE_INFO_FILE")
fi

# Fallback: detect tmux pane from TTY if not saved
if [ -z "$TMUX_PANE_ID" ]; then
  TMUX_PANE_ID=$($TMUX_CMD display-message -p '#{pane_id}' 2>/dev/null)
  # Save for next time
  if [ -n "$TMUX_PANE_ID" ]; then
    echo "$TMUX_PANE_ID" > "$PANE_INFO_FILE"
  fi
fi

# Get human-readable pane label
PANE_LABEL=""
if [ -n "$TMUX_PANE_ID" ]; then
  PANE_LABEL=$($TMUX_CMD list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index}' 2>/dev/null | awk -v id="$TMUX_PANE_ID" '$1 == id {print $2}')
fi

# Write pane info
echo "$TMUX_PANE_ID" > /tmp/claude-notify-pane

# Summarize last_assistant_message for notification
SUMMARY=$(echo "$INPUT" | /usr/bin/python3 -c "
import sys, json, re

d = json.load(sys.stdin)
msg = d.get('last_assistant_message', '')

# Strip markdown formatting
msg = re.sub(r'\`\`\`[\s\S]*?\`\`\`', '', msg)  # code blocks
msg = re.sub(r'\|[^\n]*\|', '', msg)              # tables
msg = re.sub(r'#{1,6}\s*', '', msg)               # headers
msg = re.sub(r'[\*_\`\[\]\(\)]', '', msg)         # inline formatting
msg = re.sub(r'\n+', ' ', msg)                    # newlines to spaces
msg = re.sub(r'\s+', ' ', msg).strip()            # collapse whitespace

# Take first ~100 chars, cut at word boundary
if len(msg) > 100:
    msg = msg[:100].rsplit(' ', 1)[0] + '...'

print(msg if msg else 'Done')
" 2>/dev/null || echo "Done")

# Build message with pane label
if [ -n "$PANE_LABEL" ]; then
  echo "[${PANE_LABEL}] ${SUMMARY}" > /tmp/claude-notify-message
else
  echo "$SUMMARY" > /tmp/claude-notify-message
fi

# Ensure app is running
PID=$(pgrep -f "ClaudeNotify.app/Contents/MacOS/ClaudeNotify" | head -1)
if [ -z "$PID" ]; then
  open "$NOTIFY_APP"
  sleep 2
  PID=$(pgrep -f "ClaudeNotify.app/Contents/MacOS/ClaudeNotify" | head -1)
fi

# Send SIGUSR1 to trigger notification
if [ -n "$PID" ]; then
  kill -USR1 "$PID"
fi

exit 0
