// ===== Neko Glass v10 : KWin 脚本 =====
// 快捷键 Meta+Shift+G 在"玻璃模式"(半透明)与正常之间切换。
// 真实模糊依赖 KWin 内置 "Blur" 效果 (系统设置 -> 窗口管理 -> 桌面特效)。
// 本脚本只负责窗口半透明层, 不会破坏窗口内容。

const glassOpacity = 0.92;

function isGlass(win) {
    try {
        return Math.abs(win.opacity - glassOpacity) < 0.01;
    } catch (e) {
        return false;
    }
}

function applyGlass() {
    const wins = workspace.windowList();
    wins.forEach(function (w) {
        try {
            if (w.specialWindow || w.desktopWindow || w.dock) return;
            w.opacity = glassOpacity;
        } catch (e) { }
    });
}

function clearGlass() {
    const wins = workspace.windowList();
    wins.forEach(function (w) {
        try {
            w.opacity = 1.0;
        } catch (e) { }
    });
}

function toggleGlass() {
    const wins = workspace.windowList();
    const glassCount = wins.filter(isGlass).length;
    if (glassCount > 0) {
        clearGlass();
    } else {
        applyGlass();
    }
}

if (typeof registerShortcut === "function") {
    registerShortcut(
        "Neko Glass",
        "Neko 玻璃效果开关",
        "Meta+Shift+G",
        toggleGlass
    );
} else {
    print("registerShortcut not available");
}
