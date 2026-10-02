#!/usr/bin/env bash
# 采集一次状态并发送桌面通知
DAEMON="$(cd "$(dirname "$0")/.." && pwd)/daemon/neko_core.py"
[ -x "$DAEMON" ] && exec python3 "$DAEMON" --notify
