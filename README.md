# claude-notify

macOS notification for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with Ghostty + tmux integration.

When Claude Code finishes responding, you get a macOS notification with a summary of the response. Clicking the notification brings you back to the Ghostty terminal and focuses the correct tmux pane.

## Requirements

- macOS
- [Ghostty](https://ghostty.org/) terminal
- tmux
- Claude Code

## Install

```sh
git clone https://github.com/koheisg/claude-notify.git
cd claude-notify
make install
```

This will:

1. Build `ClaudeNotify.app` (Swift, ad-hoc signed)
2. Install to `~/.claude/hooks/`
3. Add hooks to `~/.claude/settings.json`
4. Register as a login item (auto-start on login)
5. Launch the app

On first launch, macOS will ask for notification permission — allow it.

## Uninstall

```sh
make uninstall
```

## How it works

```
Claude Code responds
        │
        ▼
  Stop hook fires
  (notify-on-stop.sh)
        │
        ├─ Reads last_assistant_message
        ├─ Summarizes to ~100 chars
        ├─ Saves tmux pane ID
        └─ Sends SIGUSR1 to ClaudeNotify.app
                │
                ▼
        macOS notification
        "Claude Code"
        "[session:window.pane] Summary..."
                │
                ▼ (click)
        Ghostty activates
        + tmux pane focuses
```

### Files

| File | Role |
|---|---|
| `src/main.swift` | Background macOS app — receives SIGUSR1, sends notification, handles click |
| `hooks/save-tmux-pane.sh` | SessionStart hook — saves current tmux pane ID |
| `hooks/notify-on-stop.sh` | Stop hook — summarizes response, triggers notification |
| `resources/Info.plist` | App bundle metadata |
| `scripts/merge-settings.py` | Merges hooks into `~/.claude/settings.json` |
