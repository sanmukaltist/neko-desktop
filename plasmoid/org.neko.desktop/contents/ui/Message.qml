import QtQuick 2.15

Item {
    id: root
    property var status: ({})
    property string segment: status.segment || "work"

    function greet() {
        var seg = status.segment || "work";
        if (seg === "morning") return "🌅 早上好，主人";
        if (seg === "work") return "🥇 工作时段，主人加油";
        if (seg === "night") return "🌙 晚上好，主人";
        return "🖤 夜深了，主人早点休息";
    }
    function randomLine() {
        var L = (status.personality && status.personality.lines) ? status.personality.lines : [];
        if (L.length === 0) return "";
        return L[Math.floor(Math.random() * L.length)];
    }

    implicitHeight: greetText.implicitHeight + msgText.implicitHeight + 4

    Column {
        spacing: 2
        width: parent.width
        Text {
            id: greetText
            text: {
                var seg = root.status.segment || "work";
                if (seg === "morning") return "🌅 早上好，主人";
                if (seg === "work") return "🥇 工作时段，主人加油";
                if (seg === "night") return "🌙 晚上好，主人";
                return "🖤 夜深了，主人早点休息";
            }
            color: "#ffd6e8"; font.pixelSize: 16; font.bold: true
            width: parent.width; wrapMode: Text.WordWrap
        }
        Text {
            id: msgText
            text: ""
            color: "#e8c6d8"; font.pixelSize: 11
            width: parent.width; wrapMode: Text.WordWrap
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: 600 } }
        }
    }

    Timer {
        id: cycle
        interval: 6000; running: true; repeat: true
        onTriggered: { msgText.opacity = 0; pickTimer.start(); }
    }
    Timer {
        id: pickTimer
        interval: 350
        onTriggered: { msgText.text = root.randomLine(); msgText.opacity = 1; }
    }
    Component.onCompleted: { msgText.text = root.randomLine(); msgText.opacity = 1; }
}
