import QtQuick 2.15
import QtQuick.Particles 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1024
    height: 768
    color: "#0d0810"

    // 粒子 (基于矩形的粉点, 无需外部图片)
    ParticleSystem { id: particleSystem }

    Emitter {
        system: particleSystem
        anchors.fill: parent
        emitRate: 30
        lifeSpan: 5000
        maximumEmitted: 300
        size: 6
        velocity: AngleDirection {
            angle: 90
            magnitude: 40
            angleVariation: 360
            magnitudeVariation: 30
        }
    }

    ImageParticle {
        system: particleSystem
        source: ""  // 空 -> 纯色方点
        color: "#ff8cc6"
        alpha: 0.5
        colorVariation: 0.25
    }

    // 背景渐显
    Rectangle {
        anchors.fill: parent
        color: "#0d0810"
        opacity: 0
        NumberAnimation on opacity { to: 0.9; duration: 1500 }
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

        // 系统检查动画
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

        Item { width: 1; height: 12; }

        // 登录区
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            TextInput {
                id: nameField
                anchors.horizontalCenter: parent.horizontalCenter
                width: 240
                color: "#f5d6e6"
                text: "用户名"
                font.pixelSize: 16
                onActiveFocusChanged: if (text === "用户名") text = ""
            }
            TextInput {
                id: passField
                anchors.horizontalCenter: parent.horizontalCenter
                width: 240
                color: "#f5d6e6"
                text: "密码"
                echoMode: TextInput.Password
                font.pixelSize: 16
                onActiveFocusChanged: if (text === "密码") text = ""
            }
            ComboBox {
                id: session
                anchors.horizontalCenter: parent.horizontalCenter
                model: sessionModel
                textRole: "name"
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "登录 Login"
                onClicked: sddm.login(nameField.text, passField.text, session.currentIndex)
            }
        }
    }
}
