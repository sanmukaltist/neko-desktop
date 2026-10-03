import QtQuick 2.15
import QtQuick.Layouts 1.15

ColumnLayout {
    id: root
    property var status: ({})
    spacing: 5

    Text {
        text: "🐱 " + ((status.personality && status.personality.mood) ? ("今日心情「" + status.personality.mood + "」") : "元气满满")
        color: "#ffaad6"; font.pixelSize: 11; font.bold: true
        Layout.fillWidth: true; wrapMode: Text.WordWrap
    }

    // 状态语言 (猫娘话, 不再是冰冷进度条)
    Repeater {
        model: (status.personality && status.personality.status_lang) ? status.personality.status_lang : []
        delegate: Text {
            Layout.fillWidth: true
            text: "· " + modelData
            color: "#c9b6d6"; font.pixelSize: 10.5; wrapMode: Text.WordWrap
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: "🧪 " + (root.status.mode || "normal"); color: "#ffaad6"; font.pixelSize: 11 }
        Text { text: root.status.network ? "🌐 Online" : "📡 Offline"; color: root.status.network ? "#a8e6b0" : "#ff8cc6"; font.pixelSize: 11 }
        Item { Layout.fillWidth: true }
        Text { text: root.status.time || ""; color: "#c9a0b5"; font.pixelSize: 13; font.bold: true }
    }
}
