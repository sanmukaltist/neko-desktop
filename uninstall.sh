#!/usr/bin/env bash
# ===== Neko Desktop 卸载/恢复脚本 =====
set -euo pipefail
C_C="\033[0;36m"; C_G="\033[0;32m"; C_Y="\033[1;33m"; C_N="\033[0m"
info(){ echo -e "${C_C}[Neko]${C_N} $*"; }
ok(){   echo -e "${C_G}[✓]${C_N} $*"; }
warn(){ echo -e "${C_Y}[!]${C_N} $*"; }

info "停止并移除 Neko Core 服务..."
systemctl --user disable --now neko-core.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/neko-core.service"
systemctl --user daemon-reload 2>/dev/null || true

info "移除 Neko Desktop 数据目录..."
rm -rf "$HOME/.config/neko-desktop"

info "移除 Plasmoid / KWin 脚本..."
rm -rf "$HOME/.local/share/plasma/plasmoids/org.neko.status"
rm -rf "$HOME/.local/share/kwin/scripts/neko-glass"

# 关闭 KWin 脚本开关
kwriteconfig6 --file kwinrc --group Plugins --key neko-glassEnabled --delete 2>/dev/null || true

info "恢复最近的备份..."
BACKUP="$(ls -1dt "$HOME/.config"/neko-backup-* 2>/dev/null | head -1)"
if [ -n "$BACKUP" ]; then
  ok "找到备份: $BACKUP"
  [ -f "$BACKUP/config.fish" ] && cp -a "$BACKUP/config.fish" "$HOME/.config/fish/" || true
  [ -d "$BACKUP/fish-conf.d" ] && rm -rf "$HOME/.config/fish/conf.d" && cp -a "$BACKUP/fish-conf.d" "$HOME/.config/fish/conf.d" || true
  [ -f "$BACKUP/kitty.conf" ] && cp -a "$BACKUP/kitty.conf" "$HOME/.config/kitty/kitty.conf" || true
else
  warn "无备份, 跳过恢复"
fi

warn "SDDM 主题(若曾手动安装)需 root 移除:"
warn "  sudo rm -rf /usr/share/sddm/themes/neko-sakura"

ok "卸载完成, 重新登录生效。"
