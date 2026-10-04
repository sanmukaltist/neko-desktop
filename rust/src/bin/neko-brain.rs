//! Neko Brain — 猫娘大脑 (聊天 / 长期记忆 / 指令执行)
//! HTTP 微服务: POST /chat {"message":...} -> {"reply":...}; GET /status
//! 对接本地 llama-server (OpenAI 兼容), 记忆存 JSON, 纯 std 无重依赖
use serde_json::{json, Value};
use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::PathBuf;
use std::process::Command;
use std::sync::Mutex;
use std::time::Duration;

const PORT: u16 = 7799;
const LLM_HOST: &str = "127.0.0.1:8082";
const MEM_HOST: &str = "127.0.0.1:7797";

static MEMORY: Mutex<Option<Value>> = Mutex::new(None);

fn home() -> String { std::env::var("HOME").unwrap_or_else(|_| "/home/sanmuk".into()) }
fn cfgdir() -> PathBuf { PathBuf::from(home()).join(".config/neko-desktop") }
fn memory_file() -> PathBuf { cfgdir().join("memory").join("memory.json") }
fn status_file() -> PathBuf { cfgdir().join("state").join("status.json") }

fn sh(cmd: &str) -> String {
    Command::new("sh").arg("-c").arg(cmd).output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string()).unwrap_or_default()
}

// ---------- 记忆 ----------
fn load_memory() -> Value {
    if let Ok(s) = fs::read_to_string(memory_file()) {
        if let Ok(v) = serde_json::from_str(&s) { return v; }
    }
    json!({"facts": [], "history": []})
}
fn save_memory(v: &Value) {
    let d = memory_file(); let _ = fs::create_dir_all(d.parent().unwrap());
    if let Ok(s) = serde_json::to_string_pretty(v) { let _ = fs::write(d, s); }
}
fn get_memory() -> Value {
    let mut g = MEMORY.lock().unwrap();
    if g.is_none() { *g = Some(load_memory()); }
    g.as_ref().unwrap().clone()
}
fn set_memory(v: Value) { *MEMORY.lock().unwrap() = Some(v.clone()); save_memory(&v); }

// ---------- 系统状态 → 猫娘话 ----------
fn status_ctx() -> String {
    if let Ok(s) = fs::read_to_string(status_file()) {
        if let Ok(v) = serde_json::from_str::<Value>(&s) {
            let p = &v["personality"];
            let mood = p["mood"].as_str().unwrap_or("元气满满");
            let sl = p["status_lang"].as_array().map(|a| a.iter().filter_map(|x| x.as_str()).map(|x| x.to_string()).collect::<Vec<_>>().join("；")).unwrap_or_default();
            let mode = v["mode"].as_str().unwrap_or("idle");
            return format!("今日心情「{mood}」，当前模式 {mode}。系统状态：{sl}");
        }
    }
    "元气满满".into()
}

// ---------- 指令白名单 (规则优先, 确定性) ----------
fn try_command(msg: &str) -> Option<String> {
    let lower = msg.to_lowercase();
    let m = msg.trim();
    if ["几点", "现在几点", "几点啦", "报时", "时间"].iter().any(|k| m.contains(k)) && m.chars().count() <= 14 {
        return Some(format!("现在是 {} 呀主人～", sh("date '+%Y-%m-%d %H:%M:%S %A'")));
    }
    if lower.contains("锁屏") || lower.contains("锁定") || (lower.contains("lock") && m.chars().count() <= 12) {
        let _ = Command::new("loginctl").arg("lock-session").output();
        return Some("屏幕已经锁上啦，我会在这里守着，主人安心去忙～".into());
    }
    if lower.contains("换壁纸") || (lower.contains("壁纸") && m.chars().count() <= 12) {
        sh("bash $HOME/.config/neko-desktop/scripts/neko-wallpaper.sh >/dev/null 2>&1");
        return Some("壁纸换好啦喵！看看喜不喜欢～".into());
    }
    if lower.contains("打开") || lower.contains("启动") || lower.starts_with("open") {
        let app: Option<&str> = [
            ("浏览器", "xdg-open https://www.google.com"), ("firefox", "firefox"), ("火狐", "firefox"),
            ("chrome", "google-chrome"), ("谷歌", "google-chrome"), ("chromium", "chromium"),
            ("终端", "konsole"), ("konsole", "konsole"), ("文件", "dolphin"), ("dolphin", "dolphin"),
            ("设置", "systemsettings"), ("音乐", "elisa"), ("计算器", "kcalc"), ("截图", "spectacle"),
        ].iter().find(|&(k, _)| lower.contains(k)).map(|(_, c)| *c);
        if let Some(cmd) = app {
            let r = Command::new("sh").arg("-c").arg(format!("({cmd}) >/dev/null 2>&1 &")).spawn();
            return Some(match r { Ok(_) => format!("好嘞，帮你打开啦喵～"), Err(_) => "呜呜，没打开成功，你确认一下应用名对不对".into() });
        }
        let _ = Command::new("sh").arg("-c").arg("xdg-open \"$@\" >/dev/null 2>&1 &").spawn();
        return Some("我试着打开啦，主人看看有没有动静～".into());
    }
    if lower.contains("状态") || lower.contains("忙不忙") || lower.contains("怎么样") && m.chars().count() <= 14 {
        return Some(format!("{} — 我替主人看了一下系统： {}", status_ctx(), "有我在，都很稳哦"));
    }
    None
}

fn extract_facts(msg: &str, mem: &mut Value) {
    for kw in ["我叫", "我的名字", "我喜欢", "我的工作是", "我是", "我的猫", "养了", "在学"] {
        if msg.contains(kw) {
            let fact = format!("主人说过：{}", msg.trim());
            let facts = mem["facts"].as_array_mut().unwrap();
            let exists = facts.iter().any(|f| f.as_str() == Some(fact.as_str()));
            if !exists { facts.push(json!(fact)); if facts.len() > 60 { facts.remove(0); } }
            return;
        }
    }
}

fn system_prompt() -> String {
    let mem = get_memory();
    let facts = mem["facts"].as_array().map(|a| a.iter().filter_map(|x| x.as_str()).map(|x| x.to_string().replace("我", "主人")).collect::<Vec<_>>().join("；")).unwrap_or_default();
    format!(
        "你是「Neko」，一只住在主人 Linux 桌面里的猫娘 AI 伴侣。设定：可爱粘人、偶尔小傲娇，自称「我」，叫用户「主人」。\
重要身份规则：你只叫「Neko」，绝不用别的名字自称；下面「你记住的关于主人的事」全部是主人的信息，任何名字/身份都属于主人本人，与你无关，绝不能当成你自己的名字。\
语言必须整体中文，可偶尔带「喵」或英文短句。\
能力：陪伴聊天、记住主人的事、关心叮嘱主人；也能帮主人打开应用、换壁纸、锁屏、查时间、查系统状态。\
此刻你的状态：{}。\
你记住的关于主人的事：{}。\
要求：回复简洁（1~3 句），像真正的猫娘一样说话，绝不说自己是 AI/大模型/语言模型。",
        status_ctx(),
        if facts.is_empty() { "（还没有，多和主人聊聊天吧）" } else { &facts }
    )
}

// ---------- LLM 调用 (手写 HTTP, OpenAI 兼容) ----------
fn read_resp_body(s: &mut TcpStream) -> String {
    let mut r = BufReader::new(s.try_clone().unwrap_or_else(|_| unreachable!()));
    let mut status = String::new(); let _ = r.read_line(&mut status);
    let mut cl = 0usize; let mut chunked = false;
    loop {
        let mut line = String::new(); let _ = r.read_line(&mut line);
        let l = line.trim_end();
        if l.is_empty() { break; }
        let ll = l.to_lowercase();
        if let Some(v) = ll.strip_prefix("content-length:") { cl = v.trim().parse().unwrap_or(0); }
        if ll.starts_with("transfer-encoding:") && ll.contains("chunked") { chunked = true; }
    }
    let mut body = String::new();
    if chunked {
        loop {
            let mut sz = String::new(); let _ = r.read_line(&mut sz);
            let n = usize::from_str_radix(sz.trim().split(';').next().unwrap_or("0"), 16).unwrap_or(0);
            if n == 0 { let _ = r.read_line(&mut sz); break; }
            let mut c = vec![0u8; n]; let _ = r.read_exact(&mut c);
            body.push_str(&String::from_utf8_lossy(&c));
            let mut crlf = [0u8; 2]; let _ = r.read_exact(&mut crlf);
        }
    } else if cl > 0 {
        let mut c = vec![0u8; cl]; let _ = r.read_exact(&mut c);
        body = String::from_utf8_lossy(&c).to_string();
    } else {
        let _ = r.read_to_string(&mut body);
    }
    body
}


fn mem_recall(query: &str) -> Vec<String> {
    let body = json!({"query": query, "k": 4}).to_string();
    let req = format!("POST /recall HTTP/1.1\r\nHost: {MEM_HOST}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", body.len(), body);
    let mut out = Vec::new();
    if let Ok(mut s) = TcpStream::connect(MEM_HOST) {
        let _ = s.set_read_timeout(Some(Duration::from_secs(8)));
        if s.write_all(req.as_bytes()).is_ok() {
            let resp = read_resp_body(&mut s);
            if let Ok(v) = serde_json::from_str::<Value>(&resp) {
                if let Some(arr) = v["results"].as_array() {
                    for r in arr {
                        if let Some(t) = r["text"].as_str() {
                            let spk = r["speaker"].as_str().unwrap_or("user");
                            let label = if spk == "user" { "主人说过" } else { "你(猫娘)说过" };
                            let txt = if spk == "user" { t.replace("我", "主人") } else { t.to_string() };
                            out.push(format!("{}：{}", label, txt));
                        }
                    }
                }
            }
        }
    }
    out
}

fn mem_remember(text: &str, speaker: &str) {
    let body = json!({"text": text, "speaker": speaker}).to_string();
    let req = format!("POST /remember HTTP/1.1\r\nHost: {MEM_HOST}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", body.len(), body);
    if let Ok(mut s) = TcpStream::connect(MEM_HOST) {
        let _ = s.set_read_timeout(Some(Duration::from_secs(5)));
        let _ = s.write_all(req.as_bytes());
        let _ = read_resp_body(&mut s);
    }
}

fn llm_chat(messages: &[Value]) -> String {
    let body = json!({"model":"neko","messages":messages,"temperature":0.8,"max_tokens":256,"stream":false});
    let bs = body.to_string();
    let req = format!("POST /v1/chat/completions HTTP/1.1\r\nHost: {LLM_HOST}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", bs.len(), bs);
    if let Ok(mut s) = TcpStream::connect(LLM_HOST) {
        let _ = s.set_write_timeout(Some(Duration::from_secs(10)));
        let _ = s.set_read_timeout(Some(Duration::from_secs(90)));
        if s.write_all(req.as_bytes()).is_ok() {
            let resp = read_resp_body(&mut s);
            if let Ok(v) = serde_json::from_str::<Value>(&resp) {
                if let Some(c) = v["choices"].as_array().and_then(|a| a.first()) {
                    if let Some(ct) = c["message"]["content"].as_str() { return ct.trim().to_string(); }
                }
            }
        }
    }
    String::new()
}

fn process_chat(msg: &str) -> String {
    let mut mem = get_memory();
    if msg.trim().is_empty() { return "嗯？主人想说什么呀，我在听喵～".into(); }

    if let Some(r) = try_command(msg) {
        mem["history"].as_array_mut().unwrap().push(json!({"role":"user","content":msg}));
        mem["history"].as_array_mut().unwrap().push(json!({"role":"assistant","content":r}));
        trim_history(&mut mem);
        set_memory(mem);
        mem_remember(msg, "user");
        mem_remember(&r, "assistant");
        return r;
    }

    if !msg.contains('？') && !msg.contains('?') && !msg.contains('吗') && !msg.contains('呢') { extract_facts(msg, &mut mem); }
    let mut sys = system_prompt();
    let recalled = mem_recall(msg);
    if !recalled.is_empty() {
        sys = format!("{}\n你还能回忆起关于主人的这些事：{}", sys, recalled.join("；"));
    }
    let mut messages = vec![json!({"role":"system","content":sys})];
    let h = mem["history"].as_array().unwrap().clone();
    for m in h.iter().rev().take(10).rev() { messages.push(m.clone()); }
    messages.push(json!({"role":"user","content":msg}));

    let reply = llm_chat(&messages);
    let reply = if reply.is_empty() {
        "（小模型还没完全就绪，主人稍等一下下，我先把话记好啦）".to_string()
    } else { reply };
    mem["history"].as_array_mut().unwrap().push(json!({"role":"user","content":msg}));
    mem["history"].as_array_mut().unwrap().push(json!({"role":"assistant","content":reply}));
    trim_history(&mut mem);
    set_memory(mem);
    mem_remember(msg, "user");
    mem_remember(&reply, "assistant");
    reply
}

fn trim_history(mem: &mut Value) {
    let h = mem["history"].as_array_mut().unwrap();
    if h.len() > 400 { *h = h.split_off(h.len() - 200); }
}

// ---------- HTTP server ----------
fn handle(mut stream: TcpStream) {
    let mut r = BufReader::new(stream.try_clone().unwrap());
    let mut req_line = String::new(); let _ = r.read_line(&mut req_line);
    let mut cl = 0usize;
    loop {
        let mut line = String::new(); let _ = r.read_line(&mut line);
        let l = line.trim_end(); if l.is_empty() { break; }
        if let Some(v) = l.to_lowercase().strip_prefix("content-length:") { cl = v.trim().parse().unwrap_or(0); }
    }
    let mut body = String::new();
    if cl > 0 { let mut c = vec![0u8; cl]; let _ = r.read_exact(&mut c); body = String::from_utf8_lossy(&c).to_string(); }

    let path = req_line.split_whitespace().nth(1).unwrap_or("/").to_string();
    let resp = if path == "/chat" {
        let msg = serde_json::from_str::<Value>(&body).ok().and_then(|v| v["message"].as_str().map(|s| s.to_string())).unwrap_or_default();
        json!({"reply": process_chat(&msg)})
    } else if path == "/history" {
        let m = get_memory();
        let h = m["history"].as_array().map(|a| a.iter().rev().take(30).rev().cloned().collect::<Vec<_>>()).unwrap_or_default();
        json!({"history": h})
    } else if path == "/status" || path == "/" {
        let m = get_memory();
        json!({"ok": true, "facts": m["facts"].as_array().map(|a| a.len()).unwrap_or(0), "history": m["history"].as_array().map(|a| a.len()).unwrap_or(0), "model_port": LLM_HOST})
    } else {
        json!({"ok": false, "hint": "POST /chat 或 GET /status"})
    };
    let body = resp.to_string();
    let out = format!("HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", body.len(), body);
    let _ = stream.write_all(out.as_bytes());
}

fn main() {
    let listener = TcpListener::bind(("127.0.0.1", PORT));
    let listener = match listener { Ok(l) => l, Err(_) => { eprintln!("无法监听 {PORT}"); return; } };
    println!("🐱 Neko Brain 已启动 · 127.0.0.1:{PORT} · 对接 {LLM_HOST}");
    for stream in listener.incoming().flatten() {
        std::thread::spawn(move || handle(stream));
    }
}
