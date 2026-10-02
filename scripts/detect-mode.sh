#!/usr/bin/env bash
# 检测当前工作模式: gaming / ai / coding / normal
psout="$(ps -eo comm,args= 2>/dev/null)"
if   echo "$psout" | grep -qiE 'steam|vrchat|gamescope|lutris'; then echo "gaming"
elif echo "$psout" | grep -qiE 'ollama|vllm|llama-server|lmstudio|cuda'; then echo "ai"
elif echo "$psout" | grep -qiE '\bcode\b|vscode|pycharm|webstorm|goland|idea|clion|blender'; then echo "coding"
else echo "normal"; fi
