# 登录界面主题 (SDDM)

本目录提供经典 **SDDM** 的 QML 登录主题 `neko-sakura`。

> 注意：KDE Plasma 6.7+ 已默认改用 **Plasma Login Manager (plasmalogin)**，
> 其登录界面为内置 QML 资源，不再读取 `/usr/share/sddm/themes`。
> 若你的发行版仍使用经典 SDDM，本主题可正常使用：

```bash
sudo cp -r sddm/neko-sakura /usr/share/sddm/themes/
# 然后在 /etc/sddm.conf.d/neko.conf 写入:
#   [Theme]
#   Current=neko-sakura
```

主题特性：黑色背景 → 粒子漂浮 → 猫耳图标 → 文字 → 系统检查动画 → 登录。
