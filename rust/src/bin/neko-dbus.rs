/// neko-dbus — Neko Desktop DBus 后端
/// 注册 org.neko.desktop, 暴露 GetStatus/GetGreeting, 数据与 neko-core 同源(status.json)
use std::fs;
use zbus::blocking::Connection;
use zbus::dbus_interface;

fn status_path() -> String {
    format!("{}/.config/neko-desktop/state/status.json",
        std::env::var("HOME").unwrap_or_else(|_| "/home/sanmuk".into()))
}

struct NekoStatus;

#[dbus_interface(name = "org.neko.desktop.Status")]
impl NekoStatus {
    fn get_status(&self) -> String {
        fs::read_to_string(status_path()).unwrap_or_else(|_| "{}".into())
    }
    fn get_greeting(&self) -> String {
        if let Ok(s) = fs::read_to_string(status_path()) {
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(&s) {
                if let Some(t) = v["personality"]["text"].as_str() {
                    return t.to_string();
                }
            }
        }
        "🐱🎀 你好，主人".to_string()
    }
}

fn main() -> zbus::Result<()> {
    let conn = Connection::session()?;
    conn.request_name("org.neko.desktop")?;
    conn.object_server().at("/org/neko/desktop", NekoStatus)?;
    println!("🐱 neko-dbus 服务已注册: org.neko.desktop");
    loop { std::thread::park(); }
}
