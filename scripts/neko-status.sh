#!/usr/bin/env bash
# 输出 Neko 当前状态
DAEMON="$(cd "$(dirname "$0")/.." && pwd)/daemon/neko_core.py"
if [ -x "$DAEMON" ]; then
  exec python3 "$DAEMON" --once
else
  cat "$HOME/.config/neko-desktop/state/status.json" 2>/dev/null || echo "{}"
fi
