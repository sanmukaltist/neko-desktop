import QtQuick 2.15
import QtQuick.Layouts 1.15

ColumnLayout {
    id: root
    property var status: ({})
    property bool showGpu: plasmoid.configuration.showGpu !== false
    spacing: 5

    function barColor(kind) { return kind === "cpu" ? "#ff8cc6" : (kind === "gpu" ? "#8fc7ff" : "#a8e6b0"); }

    Text {
        text: "System " + (root.status.network ? "Ready" : "Offline")
        color: root.status.network ? "#a8e6b0" : "#ff8cc6"
        font.pixelSize: 11; font.bold: true
    }

    Text { text: "CPU " + (root.status.cpu.usage || 0) + "%" + (root.status.cpu.temp ? "  " + root.status.cpu.temp : ""); color: "#f5d6e6"; font.pixelSize: 11 }
    Rectangle {
        Layout.fillWidth: true; height: 6; radius: 3; color: "#3a2630"
        Rectangle { height: 6; radius: 3; color: root.barColor("cpu"); width: Math.max(0, Math.min(parent.width, parent.width * (root.status.cpu.usage || 0) / 100)) }
    }

    Repeater {
        model: root.showGpu ? root.status.gpus : []
        delegate: ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text {
                text: (modelData.name || "GPU") + "  " + (modelData.usage || 0) + "%  " + (modelData.vram_used_gb || 0) + "GB/" + (modelData.vram_total_gb || 0) + "GB"
                color: "#f5d6e6"; font.pixelSize: 11
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Rectangle {
                Layout.fillWidth: true; height: 6; radius: 3; color: "#2a3340"
                Rectangle { height: 6; radius: 3; color: root.barColor("gpu"); width: Math.max(0, Math.min(parent.width, parent.width * (modelData.usage || 0) / 100)) }
            }
        }
    }

    Text { text: "RAM " + (root.status.ram.usage || 0) + "%  (" + (root.status.ram.used_gb || 0) + "G/" + (root.status.ram.total_gb || 0) + "G)"; color: "#f5d6e6"; font.pixelSize: 11 }
    Rectangle {
        Layout.fillWidth: true; height: 6; radius: 3; color: "#3a2630"
        Rectangle { height: 6; radius: 3; color: root.barColor("ram"); width: Math.max(0, Math.min(parent.width, parent.width * (root.status.ram.usage || 0) / 100)) }
    }

    RowLayout {
        Text { text: "🧪 " + (root.status.mode || "normal"); color: "#ffaad6"; font.pixelSize: 11 }
        Text { text: root.status.network ? "🌐 Online" : "📡 Offline"; color: root.status.network ? "#a8e6b0" : "#ff8cc6"; font.pixelSize: 11 }
        Item { Layout.fillWidth: true }
        Text { text: root.status.time || ""; color: "#c9a0b5"; font.pixelSize: 13; font.bold: true }
    }
}
