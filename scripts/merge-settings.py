#!/usr/bin/env python3
"""Merge claude-notify hooks into ~/.claude/settings.json"""

import json
import os

SETTINGS_PATH = os.path.expanduser("~/.claude/settings.json")

SESSION_START_HOOK = {
    "matcher": "startup",
    "hooks": [
        {
            "type": "command",
            "command": "~/.claude/hooks/save-tmux-pane.sh",
            "timeout": 5,
        }
    ],
}

STOP_HOOK = {
    "hooks": [
        {
            "type": "command",
            "command": "~/.claude/hooks/notify-on-stop.sh",
            "timeout": 10,
            "async": True,
        }
    ],
}


def hooks_match(existing, target):
    """Check if an existing hook entry matches the target by command."""
    for h in existing.get("hooks", []):
        for t in target.get("hooks", []):
            if h.get("command") == t.get("command"):
                return True
    return False


def main():
    if os.path.exists(SETTINGS_PATH):
        with open(SETTINGS_PATH) as f:
            settings = json.load(f)
    else:
        settings = {}

    if "hooks" not in settings:
        settings["hooks"] = {}

    # SessionStart
    session_start = settings["hooks"].setdefault("SessionStart", [])
    if not any(hooks_match(h, SESSION_START_HOOK) for h in session_start):
        session_start.append(SESSION_START_HOOK)
        print("Added SessionStart hook")
    else:
        print("SessionStart hook already exists")

    # Stop
    stop = settings["hooks"].setdefault("Stop", [])
    if not any(hooks_match(h, STOP_HOOK) for h in stop):
        stop.append(STOP_HOOK)
        print("Added Stop hook")
    else:
        print("Stop hook already exists")

    with open(SETTINGS_PATH, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Updated {SETTINGS_PATH}")


if __name__ == "__main__":
    main()
