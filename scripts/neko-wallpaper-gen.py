#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 Neko 渐变壁纸 (纯 stdlib): 输出 SVG, 若 ImageMagick 可用则转 PNG。"""
import os, shutil, subprocess

OUT = os.path.join(os.path.expanduser("~"), ".config", "neko-desktop", "wallpapers")
THEMES = {
    "morning":    ("#ffe3f2", "#ff9ecb", "🌅", "早上好，主人  /  Good Morning"),
    "work":       ("#eaf4ff", "#a8d4ff", "🥇", "工作模式  /  Focus"),
    "night":      ("#191522", "#33204a", "🌙", "夜晚模式  /  Night"),
    "deep-night": ("#0c0914", "#1c1130", "🖤", "深夜模式  /  Deep Night"),
    "coding":     ("#0f1620", "#16404a", "🐱", "Coding Mode"),
    "ai":         ("#0f1421", "#1e3a66", "🤖", "AI Laboratory"),
    "gaming":     ("#1a0f24", "#3a1f4f", "🎮", "Gaming Mode"),
    "default":    ("#17131c", "#241a2e", "🐱🎀", "Neko Desktop"),
}

SVG = '''<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1440">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{c1}"/>
      <stop offset="1" stop-color="{c2}"/>
    </linearGradient>
  </defs>
  <rect width="2560" height="1440" fill="url(#g)"/>
  <text x="1280" y="700" font-size="260" text-anchor="middle">{emoji}</text>
  <text x="1280" y="1000" font-size="76" fill="#f5d6e6" text-anchor="middle" font-family="sans-serif">{label}</text>
</svg>
'''

def main():
    os.makedirs(OUT, exist_ok=True)
    magick = shutil.which("magick") or shutil.which("convert")
    for name, (c1, c2, emoji, label) in THEMES.items():
        svg_path = os.path.join(OUT, f"{name}.svg")
        with open(svg_path, "w", encoding="utf-8") as f:
            f.write(SVG.format(c1=c1, c2=c2, emoji=emoji, label=label))
        png_path = os.path.join(OUT, f"{name}.png")
        if magick:
            subprocess.run([magick, "-background", "none", svg_path, "-resize", "2560x1440", png_path],
                           check=False)
    print(f"🐱🎀 Wallpapers generated in {OUT} (png:{bool(magick)}, svg:yes)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
