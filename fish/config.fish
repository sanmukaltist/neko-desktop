# ===== Neko Desktop v10 : 猫娘终端主配置 =====
source /usr/share/cachyos-fish-config/cachyos-config.fish

# Fcitx5 输入法环境变量
set -x GTK_IM_MODULE fcitx
set -x QT_IM_MODULE fcitx
set -x XMODIFIERS @im=fcitx

# LM Studio CLI
set -gx PATH $PATH $HOME/.lmstudio/bin

# Neko 模块 (问候/提示符/成败反馈)
# conf.d/neko.fish 会被 fish 自动加载
