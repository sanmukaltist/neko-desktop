import QtQuick 2.15
import QtQuick.Window 2.15
import Qt.labs.settings 1.0

Window {
    id: win
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.BypassWindowManagerHint | Qt.Tool
    color: "transparent"
    width: 340
    height: 272
    visible: true
    title: "neko-overlay"

    property var status: ({
        cpu: { usage: 0, temp: "", freq: "" },
        gpus: [], ram: { usage: 0, used_gb: 0, total_gb: 0 },
        mode: "normal", segment: "work", time: "", network: false,
        personality: { banner: "🐱🎀 Neko Desktop", text: "", lines: [] }
    })
    property string dataUrl: "file://__HOME__/.config/neko-desktop/state/status.json"

    Settings {
        id: settings
        fileName: "__HOME__/.config/neko-desktop/state/overlay.conf"
        category: "overlay"
        property int posX: 60
        property int posY: 60
    }

    Component.onCompleted: {
        win.x = settings.posX
        win.y = settings.posY
        refresh()
    }

    function refresh() {
        var req = new XMLHttpRequest()
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                try { status = JSON.parse(req.responseText) } catch (e) {}
            }
        }
        req.open("GET", dataUrl)
        req.send()
    }

    Timer { interval: 3000; running: true; repeat: true; onTriggered: refresh() }

    function shortGreet() {
        var seg = status.segment || "work"
        if (seg === "morning") return "🌅 早上好，主人"
        if (seg === "work") return "🥇 工作时段，主人加油"
        if (seg === "night") return "🌙 晚上好，主人"
        return "🖤 夜深了，主人早点休息"
    }
    function firstLine() {
        if (status.personality && status.personality.lines && status.personality.lines.length > 0)
            return status.personality.lines[0]
        return (status.personality && status.personality.text) ? status.personality.text : ""
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 18
        color: "#26000000"
        border.color: "#66ff8cc6"
        border.width: 1

        Row {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.topMargin: 12
            spacing: 10
            Text { id: avatar; text: "🐱"; font.pixelSize: 44 }
            Column {
                anchors.verticalCenter: avatar.verticalCenter
                spacing: 2
                Text { text: shortGreet(); color: "#ffd6e8"; font.pixelSize: 14; font.bold: true }
                Text { text: (status.personality && status.personality.banner) ? status.personality.banner : ""; color: "#c9a0b5"; font.pixelSize: 11 }
            }
        }

        Column {
            anchors.top: parent.top
            anchors.topMargin: 86
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 5

            Text { text: "CPU " + (status.cpu.usage || 0) + "% " + (status.cpu.temp || ""); color: "#f5d6e6"; font.pixelSize: 11 }
            Rectangle { width: parent.width; height: 6; radius: 3; color: "#3a2630"
                Rectangle { height: 6; radius: 3; color: "#ff8cc6"; width: Math.max(0, Math.min(parent.width, parent.width * (status.cpu.usage || 0) / 100)) } }

            Text { text: ((status.gpus && status.gpus[0]) ? (status.gpus[0].name + " " + (status.gpus[0].usage || 0) + "% " + (status.gpus[0].vram_used_gb || 0) + "G/" + (status.gpus[0].vram_total_gb || 0) + "G") : "GPU"); color: "#f5d6e6"; font.pixelSize: 11 }
            Rectangle { width: parent.width; height: 6; radius: 3; color: "#2a3340"
                Rectangle { height: 6; radius: 3; color: "#8fc7ff"; width: Math.max(0, Math.min(parent.width, parent.width * ((status.gpus && status.gpus[0]) ? status.gpus[0].usage : 0) / 100)) } }

            Text { text: "RAM " + (status.ram.usage || 0) + "% (" + (status.ram.used_gb || 0) + "G/" + (status.ram.total_gb || 0) + "G)"; color: "#f5d6e6"; font.pixelSize: 11 }
            Rectangle { width: parent.width; height: 6; radius: 3; color: "#3a2630"
                Rectangle { height: 6; radius: 3; color: "#a8e6b0"; width: Math.max(0, Math.min(parent.width, parent.width * (status.ram.usage || 0) / 100)) } }

            Text { text: firstLine(); color: "#e8c6d8"; font.pixelSize: 10; width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideRight; maximumLineCount: 2 }

            Row {
                spacing: 10
                Text { text: "🧪 " + (status.mode || "normal"); color: "#ffaad6"; font.pixelSize: 11 }
                Text { text: (status.network ? "🌐 在线" : "📡 离线"); color: (status.network ? "#a8e6b0" : "#ff8cc6"); font.pixelSize: 11 }
                Text { text: status.time || ""; color: "#c9a0b5"; font.pixelSize: 11 }
            }
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        property real sx: 0
        property real sy: 0
        onPressed: { sx = mouseX; sy = mouseY }
        onPositionChanged: {
            if (pressed) { win.x += mouseX - sx; win.y += mouseY - sy }
        }
        onReleased: { settings.posX = win.x; settings.posY = win.y }
    }
}
