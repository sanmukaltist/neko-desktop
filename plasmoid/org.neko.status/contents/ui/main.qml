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

    property var status: ({
        cpu: { usage: 0, temp: "", freq: "" },
        gpus: [], ram: { usage: 0, used_gb: 0, total_gb: 0 },
        mode: "normal", segment: "work", time: "", network: false,
        personality: { banner: "🐱🎀 Neko Desktop", text: "", lines: [] }
    })

    function shortGreet() {
        var seg = root.status.segment || "work";
        if (seg === "morning") return "🌅 早上好";
        if (seg === "work") return "🥇 工作中";
        if (seg === "night") return "🌙 晚上好";
        return "🖤 夜深了";
    }
    function modeEmoji() {
        var m = root.status.mode || "";
        if (m === "ai") return "🧪";
        if (m === "coding") return "💻";
        if (m === "gaming") return "🎮";
        return "🐾";
    }
    function update(obj) { status = obj; }

    Plasma5Support.DataSource {
        id: statusSource
        engine: "executable"
        connectedSources: []
        interval: 3000
        property string command: "cat $HOME/.config/neko-desktop/state/status.json 2>/dev/null || echo '{}'"
        function refresh() { connectSource(command); }
        onNewData: {
            var out = data[command] ? data[command]["stdout"] : "";
            if (out && out !== "{}") {
                try { root.update(JSON.parse(out)); } catch (e) {}
            }
            disconnectSource(command);
        }
        Component.onCompleted: refresh()
    }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: statusSource.refresh() }

    CompactRepresentation {
        id: compact
        Row {
            spacing: 4
            Text { text: "🐱🎀"; font.pixelSize: 12 }
            Text { text: root.shortGreet() + " · " + root.modeEmoji() + " " + (root.status.mode || ""); color: "#ffd6e8"; font.pixelSize: 11 }
        }
    }

    FullRepresentation {
        id: hud
        ColumnLayout {
            spacing: 5
            Layout.preferredWidth: 250

            Text {
                text: (root.status.personality && root.status.personality.banner) ? root.status.personality.banner : "🐱🎀 Neko Desktop"
                color: "#ffd6e8"; font.bold: true; font.pixelSize: 14
            }
            Text { text: root.shortGreet() + "，主人"; color: "#c9a0b5"; font.pixelSize: 11 }
            Text {
                text: (root.status.personality && root.status.personality.text) ? root.status.personality.text : ""
                color: "#f5d6e6"; font.pixelSize: 10; wrapMode: Text.WordWrap
                Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 2
            }

            Text { text: "CPU  " + (root.status.cpu.usage || 0) + "%" + (root.status.cpu.temp ? "  " + root.status.cpu.temp : ""); color: "#f5d6e6"; font.pixelSize: 11 }
            Rectangle {
                Layout.fillWidth: true; height: 6; radius: 3; color: "#3a2630"
                Rectangle { height: 6; radius: 3; color: "#ff8cc6"; width: Math.max(0, Math.min(parent.width, parent.width * (root.status.cpu.usage || 0) / 100)) }
            }

            Repeater {
                model: root.status.gpus
                delegate: Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: (modelData.name || "GPU") + "  " + (modelData.usage || 0) + "%  " + (modelData.vram_used_gb || 0) + "GB/" + (modelData.vram_total_gb || 0) + "GB"
                        color: "#f5d6e6"; font.pixelSize: 11
                    }
                    Rectangle {
                        width: parent.width; height: 6; radius: 3; color: "#2a3340"
                        Rectangle { height: 6; radius: 3; color: "#8fc7ff"; width: Math.max(0, Math.min(parent.width, parent.width * (modelData.usage || 0) / 100)) }
                    }
                }
            }

            Text { text: "RAM  " + (root.status.ram.usage || 0) + "%  (" + (root.status.ram.used_gb || 0) + "G/" + (root.status.ram.total_gb || 0) + "G)"; color: "#f5d6e6"; font.pixelSize: 11 }
            Rectangle {
                Layout.fillWidth: true; height: 6; radius: 3; color: "#3a2630"
                Rectangle { height: 6; radius: 3; color: "#a8e6b0"; width: Math.max(0, Math.min(parent.width, parent.width * (root.status.ram.usage || 0) / 100)) }
            }

            RowLayout {
                Text { text: (root.status.network ? "🌐 在线" : "📡 离线"); color: root.status.network ? "#a8e6b0" : "#ff8cc6"; font.pixelSize: 11 }
                Text { text: "🧪 " + (root.status.mode || "normal"); color: "#ffaad6"; font.pixelSize: 11 }
                Item { Layout.fillWidth: true }
                Text { text: root.status.time || ""; color: "#c9a0b5"; font.pixelSize: 11 }
            }
        }
    }
}
