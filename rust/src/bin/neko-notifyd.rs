/// neko-notifyd — 通知猫娘化监听层
/// 监听会话 DBus 的 Notify 调用, 识别关键事件(下载完成/错误/包管理),
/// 以猫娘语气补发通知。不接管 org.freedesktop.Notifications (不破坏默认通知)。
use std::io::{BufRead, BufReader};
use std::process::{Child, Command, Stdio};
use std::time::Duration;

fn catgirl_notify(title: &str, body: &str) {
    let mut cmd = Command::new("notify-send");
    cmd.arg("-a").arg("Neko Desktop").arg(title);
    if !body.is_empty() { cmd.arg(body); }
    let _ = cmd.output();
}

fn classify(summary: &str, body: &str) -> Option<(String, String)> {
    let s = summary.to_lowercase();
    let b = body.to_lowercase();
    let all = format!("{s} {b}");

    let is_download = ["下载完成", "下载完毕", "已下载", "download complete", "download finished", "downloaded", "保存完成", "saved"]
        .iter().any(|k| all.contains(k));
    let is_error = ["error", "failed", "failure", "错误", "失败", "出现异常"].iter().any(|k| all.contains(k));
    let is_pkg = ["pacman", "paru", "package", "软件包", "包管理"].iter().any(|k| all.contains(k));

    if is_download {
        return Some(("🐱 文件完成啦".into(), format!("{summary}\nDownload finished.")));
    }
    if is_error && is_pkg {
        return Some(("😿 Neko 发现问题".into(), format!("Package Error\n{summary}")));
    }
    if is_error {
        return Some(("😿 Neko 发现问题".into(), format!("Error detected.\n{summary}")));
    }
    None
}

fn spawn_monitor() -> Option<Child> {
    Command::new("dbus-monitor")
        .args([
            "session",
            "type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()
}

fn main() {
    println!("🐱 neko-notifyd started — 监听中的通知事件");
    loop {
        let child = match spawn_monitor() {
            Some(c) => c,
            None => { std::thread::sleep(Duration::from_secs(3)); continue; }
        };
        let stdout = child.stdout.expect("stdout");
        let reader = BufReader::new(stdout);
        let mut strings: Vec<String> = Vec::new();
        let mut in_notify = false;

        for line in reader.lines().map_while(Result::ok) {
            if line.contains("member=Notify") && line.contains("method call") {
                in_notify = true;
                strings.clear();
                continue;
            }
            if in_notify {
                if line.trim().is_empty() || line.contains("method call time") || line.contains("signal time") {
                    in_notify = false;
                    // Notify 参数顺序: 0=app_name 1=id 2=icon 3=summary 4=body
                    if strings.len() >= 4 {
                        let summary = strings[3].clone();
                        let body = if strings.len() >= 5 { strings[4].clone() } else { String::new() };
                        if let Some((t, b)) = classify(&summary, &body) {
                            catgirl_notify(&t, &b);
                        }
                    }
                    strings.clear();
                } else if let Some(pos) = line.find("string \"") {
                    if let Some(rest) = line.get(pos + 8..) {
                        if let Some(end) = rest.find('"') {
                            strings.push(rest[..end].to_string());
                        }
                    }
                }
            }
        }
        eprintln!("dbus-monitor 退出, 3 秒后重连...");
        std::thread::sleep(Duration::from_secs(3));
    }
}
