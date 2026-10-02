import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasma5support 2.0 as Plasma5Support

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    fullRepresentation: hud
    compactRepresentation: compact

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property var status: ({ cpu: { usage: 0, model: "" }, gpus: [], ram: { usage: 0 }, mode: "normal", time: "" })

    function greeting() {
        var h = new Date().getHours();
        if (h >= 6 && h < 12) return "🌅 早上好，主人";
        if (h >= 12 && h < 18) return "🥇 工作模式，主人";
        if (h >= 18 && h < 24) return "🌙 夜晚模式，主人";
        return "🖤 夜深了，主人";
    }

    function update(obj) {
        status = obj;
    }

    Plasma5Support.DataSource {
        id: statusSource
        engine: "executable"
        connectedSources: []
        interval: 3000
        property string command: "cat $HOME/.config/neko-desktop/state/status.json 2>/dev/null || echo '{}'"
        function refresh() {
            connectSource(command);
        }
        onNewData: {
            var out = data[command] ? data[command]["stdout"] : "";
            if (out && out !== "{}") {
                try {
                    var obj = JSON.parse(out);
                    root.update(obj);
                } catch (e) { }
            }
            disconnectSource(command);
        }
        Component.onCompleted: refresh()
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: statusSource.refresh()
    }

    CompactRepresentation {
        id: compact
        Row {
            Text { text: "🐱🎀" }
            Text { text: root.status.mode ? " " + root.status.mode : ""; color: "#ffd6e8" }
        }
    }

    FullRepresentation {
        id: hud
        ColumnLayout {
            spacing: 6
            Layout.preferredWidth: 240

            Text {
                text: "🐱🎀 Neko Desktop"
                color: "#ffd6e8"
                font.bold: true
                font.pixelSize: 14
            }
            Text {
                text: root.greeting()
                color: "#c9a0b5"
                font.pixelSize: 11
            }

            function bar(name, value, color) {
                return name;
            }

            // CPU
            Text { text: "CPU  " + (root.status.cpu.usage || 0) + "%"; color: "#f5d6e6"; font.pixelSize: 11 }
            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: "#3a2630"
                Rectangle {
                    height: 6; radius: 3; color: "#ff8cc6"
                    width: Math.max(0, Math.min(parent.width, parent.width * (root.status.cpu.usage || 0) / 100))
                }
            }

            // GPU (第一块)
            Text { text: "GPU  " + ((root.status.gpus && root.status.gpus[0]) ? root.status.gpus[0].usage : 0) + "%"; color: "#f5d6e6"; font.pixelSize: 11 }
            Rectangle {
                Layout.fillWidth: true
                height: 6; radius: 3; color: "#3a2630"
                Rectangle {
                    height: 6; radius: 3; color: "#8fc7ff"
                    width: Math.max(0, Math.min(parent.width, parent.width * ((root.status.gpus && root.status.gpus[0]) ? root.status.gpus[0].usage : 0) / 100))
                }
            }

            Text {
                text: ((root.status.gpus && root.status.gpus[0])
                    ? (root.status.gpus[0].vram_used_gb + "GB/" + root.status.gpus[0].vram_total_gb + "GB")
                    : "VRAM")
                color: "#c9a0b5"; font.pixelSize: 10
            }

            // RAM
            Text { text: "RAM  " + (root.status.ram.usage || 0) + "%"; color: "#f5d6e6"; font.pixelSize: 11 }
            Rectangle {
                Layout.fillWidth: true
                height: 6; radius: 3; color: "#3a2630"
                Rectangle {
                    height: 6; radius: 3; color: "#a8e6b0"
                    width: Math.max(0, Math.min(parent.width, parent.width * (root.status.ram.usage || 0) / 100))
                }
            }

            // 模式 + 时间
            RowLayout {
                Text { text: "模式: " + (root.status.mode || "normal"); color: "#ffaad6"; font.pixelSize: 11 }
                Item { Layout.fillWidth: true }
                Text { text: root.status.time || ""; color: "#c9a0b5"; font.pixelSize: 11 }
            }
            Text {
                text: (root.status.personality && root.status.personality.banner) ? root.status.personality.banner : "🐾"
                color: "#ffd6e8"; font.pixelSize: 10; wrapMode: Text.WordWrap
            }
        }
    }
}
