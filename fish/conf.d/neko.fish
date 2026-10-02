# ===== Neko Desktop : 猫娘终端人格层 (中文 + English) =====

# ---- 欢迎语 (动态) ----
function fish_greeting
    set -l h (date +%H)
    if test $h -ge 6 -a $h -lt 12
        set_color brcyan
        echo '🌅 早上好，主人'
        echo 'Good Morning'
        echo '新的计算旅程开始啦。系统已经准备完成。'
    else if test $h -ge 12 -a $h -lt 18
        set_color yellow
        echo '🥇 工作模式，主人'
        echo 'Good Afternoon'
        echo '系统状态稳定，一起把任务搞定吧。'
    else if test $h -ge 18 -a $h -lt 24
        set_color magenta
        echo '🌙 夜晚模式启动'
        echo 'Good Evening'
        echo '主人辛苦啦，Neko 会陪你完成最后一点工作。'
    else
        set_color blue
        echo '🖤 深夜模式'
        echo 'Deep Night'
        echo '夜深了，注意休息哦。'
    end
    set_color normal

    # 系统快速检查
    set -l cpu '✓'
    command -q nvidia-smi; and set -l gpu '✓'; or set -l gpu '—'
    set -l net '✓'
    command -q ping; and ping -c1 -W1 1.1.1.1 >/dev/null 2>&1; or set net '—'

    set_color brgreen
    echo ''
    echo '系统:'
    echo "  CPU $cpu   GPU $gpu   Network $net"
    set_color normal
end

# ---- 提示符 manera user@host / pwd / time ----
function fish_prompt
    set -l last_status $status
    set -l user (whoami)
    set -l host (hostname -s 2>/dev/null; or hostname)

    set_color ffa0d0
    echo -n "🐱🎀 $user@$host"
    set_color normal
    echo

    set_color ffb6d6
    echo -n (prompt_pwd)
    set_color normal

    if test $last_status -ne 0
        set_color red
        echo -n " ✗"
        set_color normal
    end

    echo

    set_color ffc4e2
    echo -n (date +%H:%M)
    set_color normal

    echo -n ' ❯ '
end

# ---- 命令成功 / 失败 反馈 (不污染 stderr, 保留错误输出) ----
function __neko_postexec --on-event fish_postexec
    set -l code $pipestatus[1]
    if test -z "$code"
        set code $status
    end
    if test "$code" = "0"
        # 成功: 偶尔一句, 不刷屏
        if test (random 1 10) -le 3
            set_color brgreen
            echo '🐱 完成啦 Command finished.'
            set_color normal
        end
    else
        set_color red
        echo "😿 出现问题 Error detected [$code]. 让我们修复它。"
        set_color normal
    end
end
