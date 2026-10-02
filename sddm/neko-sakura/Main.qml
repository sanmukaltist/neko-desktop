import QtQuick

Rectangle {
    id: root
    color: "#0d0810"
    focus: true

    // ---- 粒子 (纯 QtQuick, 粉色漂浮点) ----
    Item {
        id: particles
        anchors.fill: parent
        Repeater {
            model: 40
            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: "#ff8cc6"
                opacity: 0.4 + Math.random() * 0.4
                x: Math.random() * particles.width
                y: particles.height + 20
                NumberAnimation on y {
                    from: particles.height + 20
                    to: -20
                    duration: 6000 + Math.random() * 10000
                    running: true
                    loops: Animation.Infinite
                }
            }
        }
    }

    // ---- 渐显遮罩 ----
    Rectangle {
        anchors.fill: parent
        color: "#0d0810"
        opacity: 0
        NumberAnimation on opacity { to: 0.85; duration: 1500 }
    }

    Column {
        anchors.centerIn: parent
        spacing: 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "🐱🎀"
            font.pixelSize: 80
            color: "#ffd6e8"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "欢迎回来，主人"
            font.pixelSize: 34
            color: "#ffd6e8"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Welcome Home, Master"
            font.pixelSize: 18
            color: "#c9a0b5"
        }

        // ---- 系统检查动画 ----
        Text {
            id: checkText
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Checking System..."
            color: "#8fc7ff"
            font.pixelSize: 14
            property int stage: 0
            Timer {
                interval: 500
                running: true
                repeat: true
                onTriggered: {
                    checkText.stage++;
                    var t = ["Checking System...", "CPU ✓", "CPU ✓  GPU ✓",
                             "CPU ✓  GPU ✓  Network ✓", "CPU ✓  GPU ✓  Network ✓  Desktop ✓",
                             "系统就绪 Ready"];
                    checkText.text = t[Math.min(checkText.stage, t.length - 1)];
                    if (checkText.stage >= t.length) running = false;
                }
            }
        }

        Item { width: 1; height: 12 }

        // ---- 登录区 ----
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 260; height: 36; radius: 6
                color: "#1f1420"
                border.color: nameField.activeFocus ? "#ff8cc6" : "#3a2630"
                TextInput {
                    id: nameField
                    anchors.fill: parent
                    anchors.margins: 8
                    color: "#f5d6e6"
                    font.pixelSize: 16
                    focus: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        text: "用户名 Username"
                        color: "#8a6678"
                        visible: nameField.text === "" && !nameField.activeFocus
                        font.pixelSize: 16
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 260; height: 36; radius: 6
                color: "#1f1420"
                border.color: passField.activeFocus ? "#ff8cc6" : "#3a2630"
                TextInput {
                    id: passField
                    anchors.fill: parent
                    anchors.margins: 8
                    color: "#f5d6e6"
                    echoMode: TextInput.Password
                    font.pixelSize: 16
                    onAccepted: root.doLogin()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        text: "密码 Password"
                        color: "#8a6678"
                        visible: passField.text === "" && !passField.activeFocus
                        font.pixelSize: 16
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 260; height: 40; radius: 8
                color: "#ff8cc6"
                Text {
                    anchors.centerIn: parent
                    text: "登录 Login"
                    color: "#1e1318"
                    font.pixelSize: 16
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doLogin()
                }
            }
        }
    }

    function doLogin() {
        if (nameField.text.trim() !== "" && passField.text !== "") {
            sddm.login(nameField.text.trim(), passField.text, sessionModel.lastIndex)
        }
    }

    Component.onCompleted: nameField.forceActiveFocus()
}
