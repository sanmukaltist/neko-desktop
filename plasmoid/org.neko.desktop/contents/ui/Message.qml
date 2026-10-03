import QtQuick 2.15

Item {
    id: root
    property var status: ({})

    function greet() {
        var seg = status.segment || "work";
        var mood = (status.personality && status.personality.mood) ? status.personality.mood : "";
        var base;
        if (seg === "morning") base = "🌅 早上好，主人";
        else if (seg === "work") base = "🥇 工作时段，主人加油";
        else if (seg === "night") base = "🌙 晚上好，主人";
        else base = "🖤 夜深了，主人早点休息";
        return mood ? (base + " · " + mood) : base;
    }
    function pool() {
        var arr = [];
        var L = (status.personality && status.personality.lines) ? status.personality.lines : [];
        var S = (status.personality && status.personality.status_lang) ? status.personality.status_lang : [];
        for (var i = 0; i < L.length; i++) arr.push("💬 " + L[i]);
        for (var j = 0; j < S.length; j++) arr.push("✨ " + S[j]);
        return arr;
    }

    implicitHeight: greetText.implicitHeight + msgText.implicitHeight + 6

    Column {
        spacing: 3
        width: parent.width
        Text {
            id: greetText
            text: root.greet()
            color: "#ffd6e8"; font.pixelSize: 15; font.bold: true
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

    property int pi: 0
    function next() {
        var P = root.pool();
        if (P.length === 0) { msgText.text = ""; return; }
        msgText.text = P[root.pi % P.length];
        msgText.opacity = 1;
        root.pi++;
    }
    Timer { interval: 6500; running: true; repeat: true; onTriggered: { msgText.opacity = 0; pickTimer.start(); } }
    Timer { id: pickTimer; interval: 350; onTriggered: next() }
    Component.onCompleted: next()
}
