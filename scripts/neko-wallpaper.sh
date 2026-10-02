#!/usr/bin/env bash
# 动态壁纸: 根据时间/模式切换 (AI实验室 / 游戏房 / 月光房 等)
WALLDIR="$HOME/.config/neko-desktop/wallpapers"
STATEFILE="$HOME/.config/neko-desktop/state/status.json"
mode="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("mode","night"))' "$STATEFILE" 2>/dev/null || echo night)"

case "$mode" in
  ai)       img="$WALLDIR/ai.png";;
  ai-lab)   img="$WALLDIR/ai.png";;
  gaming)   img="$WALLDIR/gaming.png";;
  coding)   img="$WALLDIR/coding.png";;
  morning)  img="$WALLDIR/morning.png";;
  work)     img="$WALLDIR/work.png";;
  night)    img="$WALLDIR/night.png";;
  deep-night) img="$WALLDIR/deep-night.png";;
  *)        img="$WALLDIR/default.png";;
esac
[ -f "$img" ] || img="$WALLDIR/default.png"
[ -f "$img" ] || exit 0

if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
  plasma-apply-wallpaperimage "$img"
else
  qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    "var d = desktops()[0]; d.currentConfigGroup = ['Wallpaper','org.kde.image','General']; d.writeConfig('Image','file://$img'); d.reloadConfig();" 2>/dev/null || true
fi
echo "🐱🎀 Wallpaper -> $(basename "$img")"
