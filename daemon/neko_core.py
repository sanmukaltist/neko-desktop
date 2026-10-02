#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Neko Core — 人格化桌面核心守护进程 (v10.0)

职责:
  1. 状态收集  — CPU / GPU / 内存 / 运行时间 / 网络
  2. 环境判断  — 时间分段 + 应用检测 (coding / ai / gaming)
  3. 反馈生成  — 从 personality/*.json 随机组合问候
  4. 桌面表现  — 写出 state/status.json, 发送系统通知, 驱动动态壁纸

用法:
  neko_core.py --once     # 采集一次, 输出 JSON 并写入 status.json
  neko_core.py --notify   # 采集一次并发送一条桌面通知
  neko_core.py --loop     # 常驻循环 (systemd user service 使用)
"""
import argparse
import glob
import json
import os
import random
import re
import socket
import subprocess
import time
from datetime import datetime

HOME = os.path.expanduser("~")
CONFIG_DIR = os.path.join(HOME, ".config", "neko-desktop")
STATE_DIR = os.path.join(CONFIG_DIR, "state")
REPO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def sh(cmd, timeout=3):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception:
        return ""


def load_config():
    for p in (os.path.join(CONFIG_DIR, "core", "config.json"),
              os.path.join(REPO_DIR, "core", "config.json")):
        if os.path.isfile(p):
            try:
                with open(p, encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
    return {}


def personality_dir():
    for d in (os.path.join(CONFIG_DIR, "personality"), os.path.join(REPO_DIR, "personality")):
        if os.path.isdir(d):
            return d
    return os.path.join(REPO_DIR, "personality")


def load_personality(name):
    p = os.path.join(personality_dir(), f"{name}.json")
    try:
        with open(p, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def pick(lst):
    if isinstance(lst, list) and lst:
        return random.choice(lst)
    return ""


def time_segment(hour):
    if 6 <= hour < 12:
        return "morning"
    if 12 <= hour < 18:
        return "work"
    if 18 <= hour < 24:
        return "night"
    return "deep-night"


def has_token(ps_text, names):
    for n in names:
        n = n.lower()
        if len(n) <= 5:
            if re.search(rf"\b{re.escape(n)}\b", ps_text):
                return True
        elif n in ps_text:
            return True
    return False


def detect_mode(cfg=None):
    cfg = cfg or {}
    det = cfg.get("detection", {})
    gaming = det.get("gaming", ["steam", "vrchat", "gamescope"])
    ai = det.get("ai", ["ollama", "vllm", "llama-server", "lmstudio", "cuda"])
    coding = det.get("coding", ["code", "vscode", "pycharm", "webstorm", "goland", "idea", "jetbrains", "blender"])
    ps_text = (sh("ps -eo comm,args=") or sh("ps aux")).lower()
    if has_token(ps_text, gaming):
        return "gaming"
    if has_token(ps_text, ai):
        return "ai"
    if has_token(ps_text, coding):
        return "coding"
    return None


def cpu_info():
    model = ""
    with open("/proc/cpuinfo", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if line.startswith("model name"):
                model = line.split(":", 1)[1].strip()
                break
    usage = 0.0
    try:
        s1 = open("/proc/stat").readline().split()
        time.sleep(0.15)
        s2 = open("/proc/stat").readline().split()
        total1 = sum(int(x) for x in s1[1:])
        idle1 = int(s1[4])
        total2 = sum(int(x) for x in s2[1:])
        idle2 = int(s2[4])
        d_total = total2 - total1
        d_idle = idle2 - idle1
        usage = round(max(0.0, min(100.0, 100.0 * (1 - d_idle / (d_total or 1)))), 1)
    except Exception:
        pass
    temp = ""
    for h in sorted(glob.glob("/sys/class/hwmon/hwmon*/temp*_input")):
        try:
            v = int(open(h).read().strip())
            if v > 0:
                val = v / 1000.0 if v > 200 else float(v)
                temp = f"{val:.0f}°C"
                break
        except Exception:
            continue
    freq = ""
    try:
        freq = f"{int(open('/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq').read().strip()) / 1000:.0f} MHz"
    except Exception:
        m = re.search(r"cpu MHz\s*:\s*([\d.]+)", open("/proc/cpuinfo").read())
        if m:
            freq = f"{float(m.group(1)):.0f} MHz"
    return {"model": model, "usage": usage, "temp": temp, "freq": freq}


def gpu_info():
    gpus = []
    raw = sh("nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits", timeout=5)
    if raw:
        for line in raw.splitlines():
            p = [x.strip() for x in line.split(",")]
            if len(p) >= 5 and p[0]:
                try:
                    gpus.append({
                        "name": p[0],
                        "temp": f"{p[1]}°C" if p[1] else "",
                        "usage": float(p[2]),
                        "vram_used_gb": round(int(p[3]) / 1024, 1),
                        "vram_total_gb": round(int(p[4]) / 1024, 1),
                    })
                except Exception:
                    continue
    if not gpus:
        gpus.append({"name": "GPU", "temp": "", "usage": 0.0, "vram_used_gb": 0.0, "vram_total_gb": 0.0})
    return gpus


def ram_info():
    d = {}
    with open("/proc/meminfo", encoding="utf-8", errors="ignore") as f:
        for line in f:
            k, _, v = line.partition(":")
            try:
                d[k] = int(v.strip().split()[0])
            except Exception:
                pass
    total = d.get("MemTotal", 0) / 1048576
    avail = d.get("MemAvailable", 0) / 1048576
    used = total - avail
    return {"used_gb": round(used, 1), "total_gb": round(total, 1),
            "usage": round(100 * used / total, 1) if total else 0.0}


def uptime_hms():
    try:
        s = float(open("/proc/uptime").read().split()[0])
        h, rem = divmod(int(s), 3600)
        m, _ = divmod(rem, 60)
        return h, m
    except Exception:
        return 0, 0


def net_ok():
    try:
        socket.create_connection(("1.1.1.1", 53), timeout=2).close()
        return True
    except Exception:
        return False


def compose_personality(mode, segment, upt_h):
    key = mode or segment or "random"
    data = load_personality(key) or load_personality("random") or {}
    g = pick(data.get("greetings"))
    s = pick(data.get("states"))
    e = pick(data.get("encouragements"))
    sysline = pick(data.get("system_lines"))
    if sysline:
        sysline = sysline.replace("{uptime}", str(upt_h))
    en = pick(data.get("english"))
    lines = [x for x in (g, s, sysline, e, en) if x]
    return {"key": key, "banner": data.get("banner", ""), "text": " ".join(lines), "english": en, "lines": lines}


def build_state(cfg):
    mode = detect_mode(cfg)
    hour = datetime.now().hour
    segment = time_segment(hour)
    h, m = uptime_hms()
    state = {
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "time": datetime.now().strftime("%H:%M"),
        "mode": mode or segment,
        "mode_source": "app" if mode else "time",
        "segment": segment,
        "cpu": cpu_info(),
        "gpus": gpu_info(),
        "ram": ram_info(),
        "uptime": {"hours": h, "minutes": m},
        "network": net_ok(),
        "personality": compose_personality(mode, segment, h),
    }
    return state


def write_state(state):
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(os.path.join(STATE_DIR, "status.json"), "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def notify(state):
    p = state["personality"]
    title = p.get("banner") or "🐱🎀 Neko Desktop"
    body = p.get("text") or ""
    for _ in range(1):
        try:
            subprocess.run(["notify-send", "-a", "Neko Desktop", title, body], timeout=3)
            return
        except Exception:
            pass
    try:
        subprocess.run(["kdialog", "--title", title, "--passivepopup", body, "5"], timeout=3)
    except Exception:
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--notify", action="store_true")
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--interval", type=int, default=None)
    args = ap.parse_args()

    cfg = load_config()
    interval = args.interval or int(cfg.get("interval_seconds", 15) or 15)

    if args.loop:
        last_mode = None
        while True:
            try:
                state = build_state(cfg)
                write_state(state)
                if state["mode"] != last_mode:
                    notify(state)
                    last_mode = state["mode"]
            except Exception:
                pass
            time.sleep(max(5, interval))
        return

    state = build_state(cfg)
    write_state(state)
    if args.notify:
        notify(state)
    print(json.dumps(state, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
