import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15

Window {
    id: inputWin
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    color: "transparent"
    width: 340
    height: 44
    visible: true
    title: "neko-input"

    property string chatUrl: "http://127.0.0.1:7799/chat"
    property string confUrl: "file://__HOME__/.config/neko-desktop/state/overlay.conf"

    function readPos() {
        var req = new XMLHttpRequest()
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                var px = 60, py = 40
                var mx = req.responseText.match(/posX=(\d+)/); if (mx) px = parseInt(mx[1], 10)
                var my = req.responseText.match(/posY=(\d+)/); if (my) py = parseInt(my[1], 10)
                inputWin.x = px; inputWin.y = py + 320 + 6
            }
        }
        req.open("GET", confUrl); req.send()
    }

    function sendChat() {
        var t = inputBox.text.trim()
        if (t === "") return
        inputBox.text = ""
        var req = new XMLHttpRequest()
        req.onreadystatechange = function() { if (req.readyState === XMLHttpRequest.DONE) {} }
        req.open("POST", chatUrl)
        req.setRequestHeader("Content-Type", "application/json")
        req.send(JSON.stringify({ message: t }))
        inputBox.forceActiveFocus()
    }

    Component.onCompleted: { readPos(); inputWin.requestActivate(); inputBox.forceActiveFocus() }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: readPos() }

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
