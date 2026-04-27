#!/usr/bin/env bash
# Run the game in debug-battle mode, capture a screenshot, then exit.
# Usage: bash debug_battle.sh
# Output: debug_screenshot.png in the project root

GODOT="C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe"
PROJECT="C:/Users/Kev/Documents/protocol"
SCREENSHOT="$PROJECT/debug_screenshot.png"

echo "[debug_battle] Launching..."
rm -f "$SCREENSHOT"

"$GODOT" --path "$PROJECT" -- --debug-battle
EXIT_CODE=$?

echo "[debug_battle] Godot exited with code $EXIT_CODE"

if [ -f "$SCREENSHOT" ]; then
    echo "[debug_battle] Screenshot ready: $SCREENSHOT"
else
    # Check user:// fallback
    USERDIR="$APPDATA/Godot/app_userdata/Overload Protocol/debug_screenshot.png"
    if [ -f "$USERDIR" ]; then
        cp "$USERDIR" "$SCREENSHOT"
        echo "[debug_battle] Screenshot copied from user://: $SCREENSHOT"
    else
        echo "[debug_battle] ERROR: No screenshot found"
        exit 1
    fi
fi
