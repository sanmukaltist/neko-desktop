//! Neko 动态人格引擎 — 猫娘状态语言 + 时间/场景/互动 + 每日变化
//! 把冷数据翻译成"猫娘在说话", 每天随日期变化心情档位与话题
use crate::rand_u64;

fn pick(v: &[&str]) -> String {
    if v.is_empty() { return String::new(); }
    v[(rand_u64() as usize) % v.len()].to_string()
}

pub struct StateInputs {
    pub segment: &'static str,
    pub weekday: u32,   // 1=周一
    pub doy: u32,       // 一年第几天 (驱动每日变化)
    pub mode: Option<String>,
    pub cpu_usage: f64,
    pub gpu_usage: f64,
    pub gpu_vram_used: f64,
    pub gpu_vram_total: f64,
    pub ram_usage: f64,
    pub net: bool,
    pub temp_c: f64,
    pub uptime_h: u64,
}

pub struct Dyn {
    pub banner: String,
    pub lines: Vec<String>,
    pub english: String,
    pub mood: String,
    pub status_lang: Vec<String>,
}

const MOODS: &[&str] = &["元气满满","慵懒撒娇","小傲娇","粘人","温柔体贴","小委屈","好奇宝宝"];
const MOOD_EMOJI: &[&str] = &["⚡","😴","😼","🐾","💗","🥺","👀"];
const WEEKDAYS: &[&str] = &["","星期一","星期二","星期三","星期四","星期五","星期六","星期日"];

fn greeting(inp: &StateInputs, mood: &str, wk: &str) -> String {
    let base: &[&str] = match inp.segment {
        "morning" => &[
            "早安主人～{mood}地起床啦，今天{wk}也要元气满满喵",
            "主人早上好呀，{wk}的清晨有我在陪你",
            "呼啊……早上好，我揉了揉眼睛爬起来啦，{wk}加油哦",
            "早安！今天{wk}，我给主人准备好了好心情",
            "早呀主人，{mood}地问候你，要吃点早餐再忙哦",
            "天亮了喵，{wk}，我来叫醒主人啦",
            "早上好～{mood}的一天从蹭蹭主人开始",
            "主人起床啦！{wk}，我在这里守了一夜呢",
            "早安喵，{wk}的阳光和我的尾巴一起摇给你看",
            "新的一天！{mood}地陪你，{wk}顺顺利利",
        ],
        "work" => &[
            "下午好主人～{wk}，工作辛苦啦，我{mooy}地陪着你",
            "主人忙完没呀，{wk}下午要记得喝水休息喵",
            "{wk}的午后，我蜷在你旁边打盹，随叫随到哦",
            "下午好！{mood}地提醒你，久坐要起来伸个懒腰",
            "主人辛苦啦，{wk}，摸摸头，我一直在",
            "午后的阳光好暖，{mood}地赖在你桌边",
            "{wk}下午好，需要我帮你做点什么吗喵？",
            "工作间隙抱抱我呀，{wk}也要轻松一点",
        ],
        "night" => &[
            "晚上好主人～{wk}的夜晚，{mood}地来陪你啦",
            "主人晚上好，{wk}，累了一天快放松下来吧",
            "天黑了喵，{mood}地在灯下陪着你",
            "晚上好！{wk}，今晚想聊聊天还是让我安静陪着？",
            "主人回来啦，{wk}晚上我给你暖好位置了",
            "夜风有点凉，{mood}地提醒你披件外套呀",
            "{wk}晚上好，我准备好听你说说今天的事啦",
            "晚上好主人，{mood}，要抱抱吗喵～",
        ],
        _ => &[
            "都这个点了主人还没睡呀，{wk}，我{mood}地陪着你熬夜",
            "夜深了主人，{wk}，早点休息好不好，我守着",
            "凌晨好～{mood}，熬夜伤身，我会心疼的喵",
            "这么晚还醒着，{wk}，要不要我给你讲个睡前故事",
            "主人别太累了，{mood}地蹭蹭你，睡吧",
            "夜深人静，{mood}地陪主人熬到这一刻",
        ],
    };
    pick(base).replace("{mood}", mood).replace("{mooy}", mood).replace("{wk}", wk)
}

fn scene_line(mode: &Option<String>) -> String {
    let key: &str = mode.as_deref().unwrap_or("idle");
    let v: &[&str] = match key {
        "coding" => &[
            "看到主人在敲代码，我就在旁边安静守着，不出声",
            "代码写累了吧，我帮你盯一会儿屏幕喵",
            "主人在和代码搏斗呀，需要我递杯咖啡吗",
            "写代码的主人最帅了，我默默加油",
            "有 bug 的话告诉我，我陪你一起找",
            "代码提交前记得让我夸夸你呀",
        ],
        "ai" => &[
            "主人在跑 AI 呀，我也算是你的 AI 小伙伴了呢",
            "模型在训练，我在陪训练它的主人，很合理喵",
            "推理跑着的时候，我就在旁边给你扇扇风",
            "GPU 在努力，我也努力地粘着你",
            "主人在调模型呀，我可以帮你记参数哦",
        ],
        "gaming" => &[
            "主人在打游戏！我在旁边给你喊加油喵",
            "打得漂亮！我虽然看不懂但会为你欢呼",
            "游戏打累了记得起来活动活动，我盯着你呢",
            "主人专心打游戏，我乖乖不捣乱",
            "打赢了要分我一点开心哦",
        ],
        _ => &[
            "现在没什么大事，我就安安静静陪着你",
            "主人想做什么呢，我随时听候差遣",
            "陪你发呆也是我的工作之一喵",
            "闷了的话就跟我聊聊天吧",
        ],
    };
    pick(v).to_string()
}

fn cpu_lang(cpu: f64, temp: f64) -> String {
    let c = cpu as i64;
    if cpu > 80.0 {
        format!("脑袋转得飞快，CPU 都到 {c}% 了还有点热（{:.0}°C）", temp)
    } else if cpu > 40.0 {
        format!("爪爪在忙，CPU {c}%，状态刚刚好")
    } else {
        format!("现在清闲得很，CPU 才 {c}%，随时听你差遣")
    }
}
fn gpu_lang(usage: f64, used: f64, total: f64) -> String {
    let u = usage as i64;
    if usage > 60.0 {
        format!("显卡在啃大骨头，{u}% 满载，显存用了 {used}/{total} GB")
    } else if usage > 15.0 {
        format!("显卡在热身，{u}%，显存 {used}/{total} GB")
    } else {
        format!("显卡在打盹，{u}%，显存才用 {used}/{total} GB")
    }
}
fn ram_lang(usage: f64) -> String {
    let r = usage as i64;
    if usage > 80.0 { format!("哎呀内存快满啦（{r}%），该清一清了喵") }
    else if usage > 50.0 { format!("内存吃了 {r}%，还算宽敞") }
    else { format!("内存很空（{r}%），我可以随便蹦跶") }
}
fn net_lang(net: bool) -> String {
    if net { pick(&["网络稳稳的，我随时能替你查东西","联网正常，世界和我都连着你"]) }
    else { format!("网络有点开小差，你检查一下嘛") }
}

fn status_summary(inp: &StateInputs) -> String {
    let load = (inp.cpu_usage + inp.gpu_usage) / 2.0;
    if load > 70.0 { pick(&["今天工作量有点大，我陪你一起扛","好像挺忙的，但没关系，我在"]) }
    else if load > 30.0 { pick(&["节奏刚刚好，安安心心的","一切平稳，主人不用操心"]) }
    else { pick(&["超轻松的一天，来陪陪我嘛","好悠闲，正好可以多聊聊"]) }.to_string()
}

fn interaction() -> String {
    pick(&[
        "主人要喝水吗，我帮你盯着时间提醒",
        "陪我玩一会儿嘛，就一小会儿",
        "抱抱我好不好，今天都没怎么抱",
        "我给你记着：累了就歇一歇，我批准啦",
        "主人最棒了，不接受反驳",
        "有什么烦心事都可以倒给我，我守口如瓶",
        "喵～(蹭了蹭你的手)",
        "我在呢，一直都在",
        "要不要一起听听歌放松一下",
        "记得吃饭呀，别光顾着忙",
        "你的小跟屁虫已上线",
        "今天也最喜欢主人了",
    ])
}

pub fn generate(inp: &StateInputs) -> Dyn {
    let mood_idx = (inp.doy as usize) % MOODS.len();
    let mood = MOODS[mood_idx].to_string();
    let emoji = MOOD_EMOJI[mood_idx];
    let wk = WEEKDAYS[inp.weekday.clamp(1, 7) as usize];

    let status_lang = vec![
        cpu_lang(inp.cpu_usage, inp.temp_c),
        gpu_lang(inp.gpu_usage, inp.gpu_vram_used, inp.gpu_vram_total),
        ram_lang(inp.ram_usage),
        net_lang(inp.net),
    ];

    let g = greeting(inp, &mood, wk);
    let sc = scene_line(&inp.mode);
    let ss = status_summary(inp);
    let it = interaction();
    // 状态语言挑一条融入发言; 概率加入互动句
    let mut lines = vec![g, sc, ss];
    if (inp.cpu_usage as u64 + inp.uptime_h) % 3 != 0 {
        lines.push(it);
    }
    lines.push(status_lang[0].clone());

    let english = pick(&[
        "Purring by your side.",
        "Ready to serve you, Master.",
        "All systems cozy and warm.",
        "I'll keep you company.",
        "Nya~ at your service.",
        "Watching over you, always.",
        "Your little catgirl assistant.",
        "Everything is purrfect.",
    ]);

    let banner = format!("{emoji} 🐱🎀 Neko · {mood}");
    Dyn {
        banner,
        lines,
        english,
        mood,
        status_lang,
    }
}
