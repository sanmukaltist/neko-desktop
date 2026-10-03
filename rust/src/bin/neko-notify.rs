/// neko-notify — 猫娘化通知 CLI
/// 用法: neko-notify <标题> [正文]
///       neko-notify -t 标题 -b 正文
use std::env;
use std::process::Command;

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let (mut title, mut body) = (String::new(), String::new());

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "-t" | "--title" => { if i + 1 < args.len() { title = args[i + 1].clone(); i += 2; } else { i += 1; } }
            "-b" | "--body" => { if i + 1 < args.len() { body = args[i + 1].clone(); i += 2; } else { i += 1; } }
            "-h" | "--help" => { println!("usage: neko-notify [-t title] [-b body]"); return; }
            other => { if title.is_empty() { title = other.into(); } else if body.is_empty() { body = other.into(); } else { body.push(' '); body.push_str(other); } i += 1; }
        }
    }

    if title.is_empty() { title = "Neko 通知".into(); }
    if !title.starts_with("🐱") && !title.starts_with("😿") { title = format!("🐱🎀 {title}"); }

    let mut cmd = Command::new("notify-send");
    cmd.arg("-a").arg("Neko Desktop").arg(&title);
    if !body.is_empty() { cmd.arg(&body); }
    let _ = cmd.output();
}
