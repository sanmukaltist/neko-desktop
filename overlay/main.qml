import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.0

// 根窗口: 气泡 (override-redirect 盖全屏, 只展示)
Window {
    id: bubble
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.BypassWindowManagerHint | Qt.Tool
    color: "transparent"
    width: 340
    height: 320
    visible: true
    title: "neko-overlay"

    property var status: ({ personality: { mood: "", banner: "🐱🎀 Neko", status_lang: [] }, mode: "normal", time: "" })
    property string dataUrl: "file://__HOME__/.config/neko-desktop/state/status.json"
    property string chatUrl: "http://127.0.0.1:7799/chat"
    ListModel { id: chatModel }

    Settings {
        id: settings
        fileName: "__HOME__/.config/neko-desktop/state/overlay.conf"
        category: "overlay"
        property int posX: 60
        property int posY: 40
    }

    function refresh() {
        var req = new XMLHttpRequest()
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                try { status = JSON.parse(req.responseText) } catch (e) {}
            }
        }
        req.open("GET", dataUrl); req.send()
    }

    Component.onCompleted: {
        bubble.x = settings.posX; bubble.y = settings.posY
        refresh()
        chatModel.append({ who: "neko", text: "主人好呀，想聊什么都可以跟我说喵～（请用下方输入框打字）" })
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: refresh() }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: "#26000000"
        border.color: "#66ff8cc6"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            Row {
                Layout.fillWidth: true
                spacing: 10
                Text { text: "🐱"; font.pixelSize: 36 }
                Column {
                    spacing: 2
                    Text {
                        text: (status.personality && status.personality.status_lang && status.personality.status_lang.length > 0)
                            ? ("[" + status.personality.mood + "] " + status.personality.status_lang[0]) : "🐱 你好呀，主人～"
                        color: "#ffd6e8"; font.pixelSize: 12; font.bold: true; wrapMode: Text.WordWrap; width: 250
                    }
                    Text { text: (status.personality && status.personality.banner) ? status.personality.banner : ""; color: "#c9a0b5"; font.pixelSize: 10 }
                }
                MouseArea {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    property real sx: 0; property real sy: 0
                    onPressed: { sx = mouseX; sy = mouseY }
                    onPositionChanged: { if (pressed) { bubble.x += mouseX - sx; bubble.y += mouseY - sy } }
                    onReleased: { settings.posX = bubble.x; settings.posY = bubble.y }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#33ffd6e8" }

            ListView {
                id: chatView
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: chatModel
                clip: true
                spacing: 6
                delegate: Text {
                    width: chatView.width
                    text: (model.who === "user" ? "⚘ 你：" : "🐱 ") + model.text
                    color: model.who === "user" ? "#ffaad6" : "#f0dfe8"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // 输入窗口 (嵌套, 普通置顶, 能正常打字 + 中文输入法)
    Window {
        id: inputWin
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
        transientParent: null
        color: "transparent"
        width: bubble.width
        height: 44
        x: bubble.x
        y: bubble.y + bubble.height + 6
        visible: true
        title: "neko-input"

        Component.onCompleted: { inputWin.requestActivate(); inputBox.forceActiveFocus() }

        function sendChat() {
            var t = inputBox.text.trim()
            if (t === "") return
            inputBox.text = ""
            chatModel.append({ who: "user", text: t })
            var req = new XMLHttpRequest()
            req.onreadystatechange = function() {
                if (req.readyState === XMLHttpRequest.DONE) {
                    var r = "（喵脑还没连上，稍等一下）"
                    try { r = JSON.parse(req.responseText).reply } catch (e) {}
                    chatModel.append({ who: "neko", text: r })
                }
            }
            req.open("POST", chatUrl)
            req.setRequestHeader("Content-Type", "application/json")
            req.send(JSON.stringify({ message: t }))
            inputBox.forceActiveFocus()
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#26000000"
            border.color: "#66ff8cc6"
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6
                Rectangle {
                    width: parent.width - 56; height: 28; radius: 8; color: "#22000000"; border.color: "#44ff8cc6"
                    TextInput {
                        id: inputBox
                        anchors.fill: parent; anchors.margins: 5
                        color: "#fff"; font.pixelSize: 12; clip: true
                        activeFocusOnPress: true
                        Keys.onReturnPressed: sendChat()
                    }
                }
                Rectangle {
                    width: 50; height: 28; radius: 8; color: "#ff8cc6"
                    Text { anchors.centerIn: parent; text: "发送"; color: "#1a0f1a"; font.pixelSize: 12; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: sendChat() }
                }
            }
        }
    }
}
