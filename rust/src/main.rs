/// Neko Core — 人格化桌面核心守护进程 (Rust 重写 v10.0)
/// 职责: 状态收集 | 环境判断 | 反馈生成 | 桌面表现
use serde_json::{json, Value};
use std::env;
use std::fs;
use std::net::TcpStream;
use std::path::PathBuf;
use std::process::Command;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

// ---------- 路径 ----------
fn home() -> String { env::var("HOME").unwrap_or_else(|_| "/home/sanmuk".into()) }
fn config_dir() -> PathBuf { PathBuf::from(home()).join(".config/neko-desktop") }
fn repo_dir() -> PathBuf {
    // rust/src/main.rs -> repo = rust/.. = repo
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).parent().map(|p| p.to_path_buf()).unwrap_or_default()
}

// ---------- 随机 (xorshift, 无 rand 依赖) ----------
static SEED: AtomicU64 = AtomicU64::new(0);
fn rand_u64() -> u64 {
    let mut x = SEED.load(Ordering::Relaxed);
    if x == 0 {
        let n = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_nanos() as u64).unwrap_or(0x9e3779b9) | 1;
        x = n;
    }
    x ^= x << 13; x ^= x >> 7; x ^= x << 17;
    SEED.store(x, Ordering::Relaxed);
    x
}
fn pick(v: &[String]) -> String {
    if v.is_empty() { String::new() } else { v[(rand_u64() as usize) % v.len()].clone() }
}

// ---------- shell ----------
fn sh(cmd: &str) -> String {
    Command::new("sh").arg("-c").arg(cmd).output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_default()
}

// ---------- token 匹配 (短词用词边界) ----------
fn contains_token(hay: &str, tok: &str) -> bool {
    let h = hay.as_bytes(); let t = tok.as_bytes();
    if t.is_empty() { return false; }
    let mut i = 0usize;
    while i + t.len() <= h.len() {
        if &h[i..i + t.len()] == t {
            let before_ok = i == 0 || !h[i - 1].is_ascii_alphanumeric();
            let after_ok = i + t.len() >= h.len() || !h[i + t.len()].is_ascii_alphanumeric();
            if before_ok && after_ok { return true; }
        }
        i += 1;
    }
    false
}

// ---------- 硬件采集 ----------
fn cpu_info() -> Value {
    // 型号
    let mut model = String::new();
    if let Ok(s) = fs::read_to_string("/proc/cpuinfo") {
        for line in s.lines() {
            if let Some(v) = line.strip_prefix("model name") {
                let v = v.trim().trim_start_matches(':').trim();
                if !v.is_empty() { model = v.to_string(); break; }
            }
        }
    }
    // 使用率 (两次采样)
    fn stat_sample() -> (u64, u64) {
        if let Ok(first) = fs::read_to_string("/proc/stat") {
            if let Some(line) = first.lines().next() {
                let v: Vec<u64> = line.split_whitespace().skip(1)
                    .filter_map(|x| x.parse().ok()).collect();
                let total: u64 = v.iter().sum();
                let idle = *v.get(3).unwrap_or(&0); // user,nice,system,idle,...
                return (total, idle);
            }
        }
        (0, 0)
    }
    let (t1, i1) = stat_sample();
    std::thread::sleep(Duration::from_millis(150));
    let (t2, i2) = stat_sample();
    let usage = if t2 > t1 {
        let dt = t2 - t1; let di = i2.saturating_sub(i1).min(dt);
        (100.0 * (1.0 - di as f64 / dt as f64)).clamp(0.0, 100.0)
    } else { 0.0 };

    // 温度
    let mut temp = String::new();
    let mut paths: Vec<PathBuf> = Vec::new();
    if let Ok(rd) = fs::read_dir("/sys/class/hwmon") {
        for e in rd.flatten() {
            let d = e.path();
            if let Ok(rd2) = fs::read_dir(&d) {
                for e2 in rd2.flatten() {
                    let n = e2.file_name().to_string_lossy().to_string();
                    if n.starts_with("temp") && n.ends_with("_input") { paths.push(e2.path()); }
                }
            }
        }
    }
    paths.sort();
    for p in paths {
        if let Ok(s) = fs::read_to_string(&p) {
            if let Ok(v) = s.trim().parse::<i64>() {
                if v > 0 {
                    let c = if v > 200 { v / 1000 } else { v };
                    temp = format!("{c}°C"); break;
                }
            }
        }
    }

    // 频率
    let mut freq = String::new();
    if let Ok(s) = fs::read_to_string("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq") {
        if let Ok(khz) = s.trim().parse::<f64>() { freq = format!("{:.0} MHz", khz / 1000.0); }
    }
    if freq.is_empty() {
        if let Ok(s) = fs::read_to_string("/proc/cpuinfo") {
            for line in s.lines() {
                if let Some(v) = line.strip_prefix("cpu MHz") {
                    if let Some(vv) = v.trim_start_matches(':').trim().split('.').next() {
                        freq = format!("{vv} MHz"); break;
                    }
                }
            }
        }
    }

    json!({ "model": model, "usage": ((usage * 10.0).round() / 10.0), "temp": temp, "freq": freq })
}

fn gpu_info() -> Vec<Value> {
    let raw = sh("nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits");
    let mut gpus = Vec::new();
    for line in raw.lines() {
        let p: Vec<&str> = line.split(',').map(|s| s.trim()).collect();
        if p.len() >= 5 && !p[0].is_empty() {
            let used: f64 = p[3].parse().unwrap_or(0.0);
            let total: f64 = p[4].parse().unwrap_or(0.0);
            gpus.push(json!({
                "name": p[0],
                "temp": if p[1].is_empty() { "".to_string() } else { format!("{}°C", p[1]) },
                "usage": p[2].parse::<f64>().unwrap_or(0.0),
                "vram_used_gb": ((used / 1024.0) * 10.0).round() / 10.0,
                "vram_total_gb": ((total / 1024.0) * 10.0).round() / 10.0,
            }));
        }
    }
    if gpus.is_empty() {
        gpus.push(json!({ "name": "GPU", "temp": "", "usage": 0.0, "vram_used_gb": 0.0, "vram_total_gb": 0.0 }));
    }
    gpus
}

fn ram_info() -> Value {
    let mut total_kb: f64 = 0.0; let mut avail_kb: f64 = 0.0;
    if let Ok(s) = fs::read_to_string("/proc/meminfo") {
        for line in s.lines() {
            if let Some(v) = line.strip_prefix("MemTotal:") { total_kb = v.trim().split_whitespace().next().and_then(|x| x.parse().ok()).unwrap_or(0.0); }
            if let Some(v) = line.strip_prefix("MemAvailable:") { avail_kb = v.trim().split_whitespace().next().and_then(|x| x.parse().ok()).unwrap_or(0.0); }
        }
    }
    let total = total_kb / 1048576.0;
    let used = (total_kb - avail_kb) / 1048576.0;
    let usage = if total > 0.0 { (100.0 * used / total).clamp(0.0, 100.0) } else { 0.0 };
    json!({ "used_gb": (used * 10.0).round() / 10.0, "total_gb": (total * 10.0).round() / 10.0, "usage": (usage * 10.0).round() / 10.0 })
}

fn uptime_hms() -> (u64, u64) {
    if let Ok(s) = fs::read_to_string("/proc/uptime") {
        if let Some(v) = s.split_whitespace().next().and_then(|x| x.parse::<f64>().ok()) {
            let secs = v as u64;
            return (secs / 3600, (secs % 3600) / 60);
        }
    }
    (0, 0)
}

fn net_ok() -> bool {
    TcpStream::connect_timeout(&"1.1.1.1:53".parse().unwrap(), Duration::from_secs(2)).is_ok()
}

// ---------- 模式检测 ----------
fn detect_mode(cfg: &Value) -> Option<String> {
    let det = cfg.get("detection").unwrap_or(&Value::Null);
    let list = |k: &str| -> Vec<String> {
        det.get(k).and_then(Value::as_array).map(|a| a.iter().filter_map(|x| x.as_str().map(|s| s.to_lowercase())).collect()).unwrap_or_default()
    };
    let gaming = list("gaming");
    let ai = list("ai");
    let coding = list("coding");
    let ps = sh("ps -eo comm,args=").to_lowercase();
    let has = |tokens: &[String]| tokens.iter().any(|t| if t.len() <= 5 { contains_token(&ps, t) } else { ps.contains(t.as_str()) });
    if has(&gaming) { return Some("gaming".into()); }
    if has(&ai) { return Some("ai".into()); }
    if has(&coding) { return Some("coding".into()); }
    None
}

// ---------- 人格 ----------
#[derive(serde::Deserialize)]
struct Personality {
    #[serde(default)] banner: String,
    #[serde(default)] greetings: Vec<String>,
    #[serde(default)] states: Vec<String>,
    #[serde(default)] encouragements: Vec<String>,
    #[serde(default)] system_lines: Vec<String>,
    #[serde(default)] english: Vec<String>,
}

fn personality_dir() -> PathBuf {
    let d1 = config_dir().join("personality");
    if d1.is_dir() { return d1; }
    let d2 = repo_dir().join("personality");
    if d2.is_dir() { return d2; }
    d2
}

fn load_personality(name: &str) -> Option<Personality> {
    let p = personality_dir().join(format!("{name}.json"));
    fs::read_to_string(&p).ok().and_then(|s| serde_json::from_str(&s).ok())
}

fn compose_personality(mode: &Option<String>, segment: &str, upt_h: u64) -> Value {
    let key = mode.clone().unwrap_or_else(|| segment.to_string());
    let p = load_personality(&key).or_else(|| load_personality("random")).unwrap_or(Personality {
        banner: "🐱🎀 Neko Desktop".into(), greetings: vec![], states: vec![], encouragements: vec![], system_lines: vec![], english: vec![]
    });
    let g = pick(&p.greetings);
    let s = pick(&p.states);
    let e = pick(&p.encouragements);
    let mut sysline = pick(&p.system_lines);
    if !sysline.is_empty() { sysline = sysline.replace("{uptime}", &upt_h.to_string()); }
    let en = pick(&p.english);
    let mut lines: Vec<String> = Vec::new();
    for x in [&g, &s, &sysline, &e, &en] { if !x.is_empty() { lines.push(x.clone()); } }
    let text = lines.join(" ");
    json!({ "key": key, "banner": p.banner, "text": text, "english": en, "lines": lines })
}

// ---------- 时间分段 ----------
fn time_segment(h: u32) -> &'static str {
    if (6..12).contains(&h) { "morning" }
    else if (12..18).contains(&h) { "work" }
    else if (18..24).contains(&h) { "night" }
    else { "deep-night" }
}

// ---------- 配置 ----------
fn load_config() -> Value {
    let p = config_dir().join("core/config.json");
    let rp = repo_dir().join("core/config.json");
    for p in [&p, &rp] {
        if let Ok(s) = fs::read_to_string(p) {
            if let Ok(v) = serde_json::from_str(&s) { return v; }
        }
    }
    json!({})
}

// ---------- 状态 ----------
fn build_state(cfg: &Value) -> Value {
    let mode = detect_mode(cfg);
    let hour: u32 = sh("date +%H").trim().parse().unwrap_or(12);
    let segment = time_segment(hour);
    let (h, m) = uptime_hms();
    let now = sh("date +%Y-%m-%dT%H:%M:%S");
    let hms = sh("date +%H:%M");
    json!({
        "timestamp": now,
        "time": hms,
        "mode": mode.clone().unwrap_or_else(|| segment.to_string()),
        "mode_source": if mode.is_some() { "app" } else { "time" },
        "segment": segment,
        "cpu": cpu_info(),
        "gpus": gpu_info(),
        "ram": ram_info(),
        "uptime": { "hours": h, "minutes": m },
        "network": net_ok(),
        "personality": compose_personality(&mode, segment, h),
    })
}

fn write_state(state: &Value) {
    let d = config_dir().join("state");
    let _ = fs::create_dir_all(&d);
    if let Ok(s) = serde_json::to_string_pretty(state) {
        let _ = fs::write(d.join("status.json"), s);
    }
}

fn notify(state: &Value) {
    let p = state.get("personality").unwrap_or(&Value::Null);
    let title = p.get("banner").and_then(Value::as_str).map(|s| s.to_string()).unwrap_or_else(|| "🐱🎀 Neko Desktop".into());
    let body = p.get("text").and_then(Value::as_str).unwrap_or("").to_string();
    let _ = Command::new("notify-send").args(["-a", "Neko Desktop", &title, &body]).output();
    let _ = Command::new("kdialog").args(["--title", &title, "--passivepopup", &body, "5"]).output();
}

// ---------- main ----------
fn main() {
    let args: Vec<String> = env::args().collect();
    let once = args.iter().any(|a| a == "--once");
    let notify_flag = args.iter().any(|a| a == "--notify");
    let loop_mode = args.iter().any(|a| a == "--loop");
    let interval = args.iter().position(|a| a == "--interval").and_then(|i| args.get(i + 1)).and_then(|x| x.parse::<u64>().ok());

    let cfg = load_config();
    let iv = interval.unwrap_or_else(|| cfg.get("interval_seconds").and_then(Value::as_u64).unwrap_or(15)).max(5);

    if loop_mode {
        let mut last_mode: Option<String> = None;
        loop {
            if let Ok(state) = std::panic::catch_unwind(|| build_state(&cfg)) {
                write_state(&state);
                let m = state.get("mode").and_then(Value::as_str).map(|s| s.to_string());
                if m != last_mode { notify(&state); last_mode = m; }
            }
            std::thread::sleep(Duration::from_secs(iv));
        }
    }

    let state = build_state(&cfg);
    write_state(&state);
    if notify_flag { notify(&state); }
    if once || (!notify_flag && !loop_mode) {
        if let Ok(s) = serde_json::to_string_pretty(&state) { println!("{s}"); }
    }
}
