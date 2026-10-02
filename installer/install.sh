#!/usr/bin/env bash
# ===== Neko Desktop v10 一键安装器 (安全安装: 检测→备份→安装→测试→恢复) =====
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.config/neko-desktop"
DATE="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config/neko-backup-$DATE"
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/org.neko.status"
KWIN_DIR="$HOME/.local/share/kwin/scripts/neko-glass"
SDDM_DIR="/usr/share/sddm/themes/neko-sakura"

C_C="\033[0;36m"; C_G="\033[0;32m"; C_Y="\033[1;33m"; C_R="\033[0;31m"; C_N="\033[0m"
info(){ echo -e "${C_C}[Neko]${C_N} $*"; }
ok(){   echo -e "${C_G}[✓]${C_N} $*"; }
warn(){ echo -e "${C_Y}[!]${C_N} $*"; }
die(){  echo -e "${C_R}[✗]${C_N} $*"; exit 1; }

info "🐱🎀 Neko Desktop v10.0 Installer"
info "Welcome Home, Master ♡"
echo

# ---- 1. 检测 ----
info "检测系统环境..."
DISTRO="$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')"
[ -n "$WAYLAND_DISPLAY" ] && SESSION_TYPE="wayland" || SESSION_TYPE="x11"
command -v python3 >/dev/null || die "需要 python3"
command -v nvidia-smi >/dev/null && GPU="nvidia" || GPU="unknown"
ok "系统: $DISTRO | 会话: $SESSION_TYPE | GPU: $GPU"

# ---- 2. 备份 ----
info "备份现有配置到 $BACKUP ..."
mkdir -p "$BACKUP"
[ -d "$DEST" ]      && cp -a "$DEST" "$BACKUP/neko-desktop" 2>/dev/null || true
[ -f "$HOME/.config/fish/config.fish" ] && cp -a "$HOME/.config/fish/config.fish" "$BACKUP/" 2>/dev/null || true
[ -d "$HOME/.config/fish/conf.d" ] && cp -a "$HOME/.config/fish/conf.d" "$BACKUP/fish-conf.d" 2>/dev/null || true
[ -f "$HOME/.config/kitty/kitty.conf" ] && cp -a "$HOME/.config/kitty/kitty.conf" "$BACKUP/" 2>/dev/null || true
[ -d "$PLASMOID_DIR" ] && cp -a "$PLASMOID_DIR" "$BACKUP/org.neko.status" 2>/dev/null || true
[ -d "$KWIN_DIR" ] && cp -a "$KWIN_DIR" "$BACKUP/neko-glass" 2>/dev/null || true
ok "备份完成"

# ---- 3. 安装 ----
info "安装 Neko Core ..."
mkdir -p "$DEST"
cp -r "$BASE/core"      "$DEST/"
cp -r "$BASE/personality" "$DEST/"
cp -r "$BASE/daemon"    "$DEST/"
cp -r "$BASE/scripts"   "$DEST/"
chmod +x "$DEST/daemon/neko_core.py" "$DEST/scripts/"*.sh "$DEST/scripts/"*.py 2>/dev/null || true

info "安装 Fish / Kitty 配置 ..."
mkdir -p "$HOME/.config/fish/conf.d" "$HOME/.config/kitty"
cp "$BASE/fish/config.fish"       "$HOME/.config/fish/config.fish"
cp "$BASE/fish/conf.d/neko.fish"  "$HOME/.config/fish/conf.d/neko.fish"
cp "$BASE/kitty/kitty.conf"       "$HOME/.config/kitty/kitty.conf"

info "安装 systemd user service ..."
mkdir -p "$HOME/.config/systemd/user"
sed "s|%h|$HOME|g" "$BASE/services/neko-core.service" > "$HOME/.config/systemd/user/neko-core.service"
systemctl --user daemon-reload || true
systemctl --user enable --now neko-core.service 2>/dev/null || warn "服务启动失败(可能无图形会话), 稍后可手动启动"

info "安装 Plasmoid / KWin 脚本 ..."
mkdir -p "$(dirname "$PLASMOID_DIR")"
rm -rf "$PLASMOID_DIR"; cp -r "$BASE/plasmoid/org.neko.status" "$PLASMOID_DIR"
mkdir -p "$(dirname "$KWIN_DIR")"
rm -rf "$KWIN_DIR"; cp -r "$BASE/kwin/neko-glass" "$KWIN_DIR"

info "生成壁纸 ..."
python3 "$DEST/scripts/neko-wallpaper-gen.py" || true

# ---- 4. SDDM (需 root) ----
if [ "$(id -u)" -eq 0 ]; then
  info "安装 SDDM 主题 ..."
  mkdir -p "/usr/share/sddm/themes"
  rm -rf "$SDDM_DIR"; cp -r "$BASE/sddm/neko-sakura" "$SDDM_DIR"
  ok "SDDM 主题已安装 (在 systemsettings 里选择 Neko Sakura)"
else
  warn "SDDM 主题需要 root。用 sudo 重新运行本脚本安装, 或手动:"
  warn "  sudo cp -r '$BASE/sddm/neko-sakura' /usr/share/sddm/themes/"
fi

echo
ok "安装完成！"
info "重启 KDE 会话或重新登录以生效。"
info "恢复备份: cp -a '$BACKUP/.' 对应位置"
