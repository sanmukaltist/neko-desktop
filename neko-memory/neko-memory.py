#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Neko LSTM 记忆状态机 — torch 手写 LSTM 处理长期记忆
- 句子 LSTM 编码对话 -> 记忆 LSTM 递归累积记忆状态(压缩+遗忘)
- 在线自监督训练: 从记忆状态重建最近用户消息(记忆压缩)
- 召回: 关键词重叠 + LSTM 向量余弦 + 时间衰减 综合打分
HTTP: POST /remember  POST /recall  GET /state   (127.0.0.1:7797)
"""
import json, os, math, time
import torch
import torch.nn as nn
from http.server import BaseHTTPRequestHandler, HTTPServer

torch.set_num_threads(2)
HOME = os.path.expanduser("~")
BASE = os.path.join(HOME, ".config/neko-desktop/memory")
VEC_FILE = os.path.join(BASE, "memory_vec.json")
CKPT_FILE = os.path.join(BASE, "lstm_checkpoint.pt")
PORT = 7797
EMB, HID = 64, 64
os.makedirs(BASE, exist_ok=True)

_BASE_CHARS = " 的一是在不了有和人这中大为上个国我以要他时来用们生到作地于出就分对成会可主发年动同工也能下过子说产种面而方后多定行学法所民得经十三之进着等部度家电力里如水化高自二理起小物现实加量都两体制机当使点从业本去把性好应开它合还因由其些然前外天政四日那社义事平形相全表间样与关各重新线内数正心反你明看原又么利比或但质气第向道命此变条只没结解问意建月公无系军很情者最立代想已通并提直题党程展五果料象员革位入常文总次品式活设及管特件长求老头基资边流路级少图山统接知较将组见计别她手角期根论运农指几九区强放决西被干做必战先回则任取据处队南给色光门即保治北造百规热领七海口东导器压志世金增争济阶油思术极交受联什认六共权收证改清己美再采转更单风切打白教速花带安场身车例真务具万每目至达走积示议声报斗完类八离华名确才科张信马节话米整空元况今集温传土许步群广石记需段研界拉林律叫且究观越织装影算低持音众书布复容儿须际商非验连断深难近矿千周委素技备半办青省列习响约支般史感劳便团往酸历市克何除消构府称太准精值号率族维划选标写存候毛亲快效斯院查江型眼王按格养易置派层片始却专状育厂京识适属圆包火住调满县局照参红细引听该铁价严龙飞"
_BASE_CHARS = _BASE_CHARS.replace(" ", "").replace("\n", "")
for _c in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ，。！？、；：（）【】\"'…·喵主人猫陪我妮":
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

def feat_for(ts, speaker):
    dt = 0.0 if not memories else max(0.0, min(10.0, (ts - memories[-1]["ts"]) / 3600.0))
    spk = 1.0 if speaker == "user" else -1.0
    return [dt, spk]

def save_all():
    json.dump(memories, open(VEC_FILE, "w"), ensure_ascii=False)
    torch.save({"model": model.state_dict(), "optim": optim.state_dict(),
                "mem_h": mem_h, "mem_c": mem_c, "steps": train_steps}, CKPT_FILE)

def train_step():
    global train_steps, mem_h, mem_c
    if len(memories) < 4: return
    T = min(16, len(memories))
    seg = memories[-T:]
    vs, fs = [], []
    for m in seg:
        vs.append(torch.tensor(m["vec"], dtype=torch.float32))
        fs.append(m["feat"])
    vx = torch.stack(vs).unsqueeze(0)
    fx = torch.tensor(fs, dtype=torch.float32).unsqueeze(0)
    model.train()
    x = torch.cat([vx, fx], dim=-1)
    _, (h, c) = model.mem_lstm(x)
    target = None
    for m in reversed(seg):
        if m["speaker"] == "user":
            target = torch.tensor(m["vec"], dtype=torch.float32)
            break
    if target is None: return
    pred = model.decoder(h.squeeze(0)[-1])
    loss = ((pred - target) ** 2).mean()
    optim.zero_grad(); loss.backward(); optim.step()
    mem_h, mem_c = h, c
    train_steps += 1

def cos(a, b):
    na = torch.norm(a); nb = torch.norm(b)
    if na == 0 or nb == 0: return 0.0
    return float((a * b).sum() / (na * nb))

def keyword_score(q, text):
    qs = set(q); ts = set(text)
    if not qs: return 0.0
    return len(qs & ts) / len(qs)

@torch.no_grad()
def encode_vec(text):
    return model.encode(encode_text(text)).squeeze(0).tolist()

@torch.no_grad()
def recall(query, k=5):
    q = query
    now = time.time()
    scored = []
    for m in memories:
        ks = keyword_score(q, m["text"])
        cs = cos(torch.tensor(m["vec"]), torch.tensor(encode_vec(q)))
        age = max(0.0, (now - m["ts"]) / 86400.0)
        recency = math.exp(-age / 5.0)
        s = 0.5 * ks + 0.35 * cs + 0.15 * recency
        scored.append((s, m["text"], m["speaker"]))
    scored.sort(key=lambda x: -x[0])
    return [{"score": round(s, 3), "text": t, "speaker": sp} for s, t, sp in scored[:k] if s > 0.15]

def remember(text, speaker, ts=None):
    global mem_h, mem_c
    ts = ts or time.time()
    if not text.strip(): return
    v = encode_vec(text)
    f = feat_for(ts, speaker)
    memories.append({"text": text.strip(), "speaker": speaker, "ts": ts, "vec": v, "feat": f})
    if len(memories) > 300:
        memories[:] = memories[-300:]
    model.eval()
    vt = torch.tensor([v], dtype=torch.float32).unsqueeze(1)
    ft = torch.tensor([f], dtype=torch.float32).unsqueeze(1)
    x = torch.cat([vt, ft], dim=-1)
    _, (hh, cc) = model.mem_lstm(x)
    mem_h, mem_c = hh, cc
    train_step()
    save_all()

class H(BaseHTTPRequestHandler):
    def _send(self, obj):
        b = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)
    def log_message(self, *a): pass
    def do_GET(self):
        if self.path.startswith("/state"):
            self._send({"memories": len(memories), "train_steps": train_steps, "hidden_dim": HID, "vocab": VOCAB})
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
    print(f"neko-memory LSTM :{PORT} vocab={VOCAB} memories={len(memories)}")
    HTTPServer(("127.0.0.1", PORT), H).serve_forever()
