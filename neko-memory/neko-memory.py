#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Neko LSTM 记忆状态机 v2 — 双向联想 + 模糊匹配
- 句子 LSTM 编码 + 记忆 LSTM 递归状态(压缩/遗忘/在线训练)
- 模糊匹配: 字符 1-gram + 2-gram 加权重叠 (不必逐字精确)
- 双向联想: 记忆间关联图(共现+向量), recall 由直接命中扩展出关联记忆
- 置信度分层: 强相关/相关/模糊/联想
HTTP: POST /remember  POST /recall  GET /state  (127.0.0.1:7797)
"""
import json, os, math, time
import torch
import torch.nn as nn
from http.server import BaseHTTPRequestHandler, HTTPServer

torch.set_num_threads(2)
HOME = os.path.expanduser("~")
BASE = os.path.join(HOME, ".config/neko-desktop/memory")
VEC_FILE = os.path.join(BASE, "memory_vec.json")
ASSOC_FILE = os.path.join(BASE, "memory_assoc.json")
CKPT_FILE = os.path.join(BASE, "lstm_checkpoint.pt")
PORT = 7797
EMB, HID = 64, 64
os.makedirs(BASE, exist_ok=True)

_BASE_CHARS = " 的一是在不了有和人这中大为上个国我以要他时来用们生到作地于出就分对成会可主发年动同工也能下过子说产种面而方后多定行学法所民得经十三之进着等部度家电力里如水化高自二理起小物现实加量都两体制机当使点从业本去把性好应开它合还因由其些然前外天政四日那社义事平形相全表间样与关各重新线内数正心反你明看原又么利比或但质气第向道命此变条只没结解问意建月公无系军很情者最立代想已通并提直题党程展五果料象员革位入常文总次品式活设及管特件长求老头基资边流路级少图山统接知较将组见计别她手角期根论运农指几九区强放决西被干做必战先回则任取据处队南给色光门即保治北造百规热领七海口东导器压志世金增争济阶油思术极交受联什认六共权收证改清己美再采转更单风切打白教速花带安场身车例真务具万每目至达走积示议声报斗完类八离华名确才科张信马节话米整空元况今集温传土许步群广石记需段研界拉林律叫且究观越织装影算低持音众书布复容儿须际商非验连断深难近矿千周委素技备半办青省列习响约支般史感劳便团往酸历市克何除消构府称太准精值号率族维划选标写存候毛亲快效斯院查江型眼王按格养易置派层片始却专状育厂京识适属圆包火住调满县局照参红细引听该铁价严龙飞"
_BASE_CHARS = _BASE_CHARS.replace(" ", "").replace("\n", "")
for _c in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ，。！？、；：（）【】\"'…·喵主人猫陪我妮英雄联盟":
    if _c not in _BASE_CHARS:
        _BASE_CHARS += _c

def build_c2i():
    c2i = {c: i for i, c in enumerate(list(_BASE_CHARS))}
    return c2i, len(c2i)

C2I, VOCAB = build_c2i()

def encode_text(text):
    return [C2I.get(c, 0) for c in text[:200]]

class NekoMemory(nn.Module):
    def __init__(self, vocab):
        super().__init__()
        self.emb = nn.Embedding(vocab, EMB)
        self.sent_lstm = nn.LSTM(EMB, HID, batch_first=True)
        self.mem_lstm = nn.LSTM(HID + 2, HID, batch_first=True)
        self.decoder = nn.Linear(HID, HID)
    def encode(self, ids):
        if not ids: ids = [0]
        x = self.emb(torch.tensor([ids], dtype=torch.long))
        _, (h, _) = self.sent_lstm(x)
        return h.squeeze(0)
    def mem_step(self, v, feat):
        x = torch.cat([v, feat], dim=-1)
        _, (h, c) = self.mem_lstm(x)
        return h, c

model = NekoMemory(VOCAB)
optim = torch.optim.Adam(model.parameters(), lr=1e-3)
mem_h = torch.zeros(1, HID)
mem_c = torch.zeros(1, HID)
train_steps = 0
if os.path.exists(CKPT_FILE):
    try:
        ck = torch.load(CKPT_FILE, map_location="cpu")
        model.load_state_dict(ck["model"]); optim.load_state_dict(ck["optim"])
        mem_h = ck["mem_h"]; mem_c = ck["mem_c"]; train_steps = ck.get("steps", 0)
    except Exception as e:
        print("load ckpt fail", e)

memories = []
if os.path.exists(VEC_FILE):
    try: memories = json.load(open(VEC_FILE))
    except Exception: memories = []

# 关联图: {str(idx): {str(nb): score}}  双向(冗余存储)
assoc = {}
if os.path.exists(ASSOC_FILE):
    try: assoc = json.load(open(ASSOC_FILE))
    except Exception: assoc = {}

def feat_for(ts, speaker):
    dt = 0.0 if not memories else max(0.0, min(10.0, (ts - memories[-1]["ts"]) / 3600.0))
    return [dt, 1.0 if speaker == "user" else -1.0]

def save_all():
    json.dump(memories, open(VEC_FILE, "w"), ensure_ascii=False)
    json.dump(assoc, open(ASSOC_FILE, "w"))
    torch.save({"model": model.state_dict(), "optim": optim.state_dict(),
                "mem_h": mem_h, "mem_c": mem_c, "steps": train_steps}, CKPT_FILE)

# ---------- 模糊匹配 ----------
def ngram(s, n):
    if len(s) < n: return set()
    return {s[i:i+n] for i in range(len(s)-n+1)}

def fuzzy_score(q, text):
    """字符 1-gram + 2-gram 加权重叠, 容忍用词/语序差异"""
    q1, t1 = set(q), set(text)
    s1 = len(q1 & t1) / max(1, len(q1))
    q2, t2 = ngram(q, 2), ngram(text, 2)
    s2 = len(q2 & t2) / max(1, len(q2))
    return 0.5 * s1 + 0.5 * s2

def cos(a, b):
    na = torch.norm(a); nb = torch.norm(b)
    if na == 0 or nb == 0: return 0.0
    return float((a * b).sum() / (na * nb))

def link_strength(ia, ib):
    """记忆间双向关联强度: 向量语义 + 双向模糊词面"""
    a, b = memories[ia], memories[ib]
    cs = max(0.0, cos(torch.tensor(a["vec"]), torch.tensor(b["vec"])))
    fs = 0.5 * fuzzy_score(a["text"], b["text"]) + 0.5 * fuzzy_score(b["text"], a["text"])
    return round(0.55 * cs + 0.45 * fs, 4)

def add_link(i, j, s):
    def put(x, y):
        d = assoc.setdefault(str(x), {})
        d[str(y)] = max(s, d.get(str(y), 0.0))
    put(i, j); put(j, i)

# ---------- 训练 ----------
def train_step():
    global train_steps, mem_h, mem_c
    if len(memories) < 4: return
    T = min(16, len(memories))
    seg = memories[-T:]
    vs = [torch.tensor(m["vec"], dtype=torch.float32) for m in seg]
    fs = [m["feat"] for m in seg]
    vx = torch.stack(vs).unsqueeze(0)
    fx = torch.tensor(fs, dtype=torch.float32).unsqueeze(0)
    model.train()
    x = torch.cat([vx, fx], dim=-1)
    _, (h, c) = model.mem_lstm(x)
    target = None
    for m in reversed(seg):
        if m["speaker"] == "user":
            target = torch.tensor(m["vec"], dtype=torch.float32); break
    if target is None: return
    pred = model.decoder(h.squeeze(0)[-1])
    loss = ((pred - target) ** 2).mean()
    optim.zero_grad(); loss.backward(); optim.step()
    mem_h, mem_c = h, c
    train_steps += 1

# ---------- 编码 + 记忆 ----------
@torch.no_grad()
def encode_vec(text):
    return model.encode(encode_text(text)).squeeze(0).tolist()

def remember(text, speaker, ts=None):
    global mem_h, mem_c
    ts = ts or time.time()
    if not text.strip(): return
    text = text.strip()
    v = encode_vec(text)
    f = feat_for(ts, speaker)
    idx = len(memories)
    memories.append({"text": text, "speaker": speaker, "ts": ts, "vec": v, "feat": f})
    # 增量建立双向关联
    for j in range(idx):
        s = link_strength(idx, j)
        if s > 0.12:
            add_link(idx, j, s)
    if len(memories) > 300:
        memories[:] = memories[-300:]
        assoc.clear()   # 截断后索引失效, 重建
        for a in range(len(memories)):
            for b in range(a+1, len(memories)):
                s = link_strength(a, b)
                if s > 0.12: add_link(a, b, s)
    model.eval()
    vt = torch.tensor([v], dtype=torch.float32).unsqueeze(1)
    ft = torch.tensor([f], dtype=torch.float32).unsqueeze(1)
    x = torch.cat([vt, ft], dim=-1)
    _, (hh, cc) = model.mem_lstm(x)
    mem_h, mem_c = hh, cc
    train_step()
    save_all()

# ---------- 召回: 直接命中 + 双向联想 + 模糊置信度 ----------
@torch.no_grad()
def recall(query, k=5):
    now = time.time()
    qv = torch.tensor(encode_vec(query))
    scored = []
    for i, m in enumerate(memories):
        fs = fuzzy_score(query, m["text"])
        cs = max(0.0, cos(qv, torch.tensor(m["vec"])))
        recency = math.exp(-max(0.0, (now - m["ts"]) / 86400.0) / 5.0)
        s = 0.45 * fs + 0.35 * cs + 0.20 * recency
        scored.append((round(s, 4), i))
    scored.sort(key=lambda x: -x[0])

    def conf(s):
        return "强相关" if s > 0.45 else ("相关" if s > 0.25 else "模糊")

    results, seen = [], set()
    for s, i in scored[:k]:
        if s < 0.08: break
        m = memories[i]
        results.append({"score": s, "text": m["text"], "speaker": m["speaker"], "confidence": conf(s), "source": "direct", "_idx": i})
        seen.add(i)
    for r in list(results):
        src_idx = r.pop("_idx")
        for nb_str, ls in assoc.get(str(src_idx), {}).items():
            ni = int(nb_str)
            if ni in seen or ls < 0.10: continue
            m = memories[ni]
            results.append({"score": round(ls, 3), "text": m["text"], "speaker": m["speaker"], "confidence": "联想", "source": "associate", "via": r["text"]})
            seen.add(ni)
    return results

# ---------- HTTP ----------
class H(BaseHTTPRequestHandler):
    def _send(self, obj):
        b = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers(); self.wfile.write(b)
    def log_message(self, *a): pass
    def do_GET(self):
        if self.path.startswith("/state"):
            self._send({"memories": len(memories), "train_steps": train_steps, "assoc_links": sum(len(v) for v in assoc.values()) // 2, "vocab": VOCAB})
        else:
            self._send({"ok": False})
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n).decode("utf-8", "ignore")
        try: d = json.loads(body)
        except Exception: d = {}
        if self.path == "/remember":
            remember(d.get("text", ""), d.get("speaker", "user"), d.get("ts"))
            self._send({"ok": True, "memories": len(memories)})
        elif self.path == "/recall":
            self._send({"results": recall(d.get("query", ""), int(d.get("k", 5)))})
        else:
            self._send({"ok": False})

if __name__ == "__main__":
    print(f"neko-memory LSTM v2 :{PORT} vocab={VOCAB} memories={len(memories)} links={sum(len(v) for v in assoc.values())//2}")
    HTTPServer(("127.0.0.1", PORT), H).serve_forever()
