import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasma5support 2.0 as Plasma5Support

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    fullRepresentation: fullComp
    compactRepresentation: compactComp

    Plasmoid.backgroundHints: PlasmaCore.Types.ConfigurableBackground | PlasmaCore.Types.ShadowBackground

    property var status: ({
        cpu: { usage: 0, temp: "", freq: "" },
        gpus: [], ram: { usage: 0, used_gb: 0, total_gb: 0 },
        mode: "normal", segment: "work", time: "", network: false,
        personality: { banner: "🐱🎀 Neko Desktop", mood: "", text: "", lines: [], status_lang: [] }
    })
    property int refreshMs: plasmoid.configuration.refreshInterval || 3000
    property string chatUrl: "http://127.0.0.1:7799/chat"

    function update(obj) { status = obj; }

    // ---- 聊天 ----
    ListModel { id: chatModel }
    function sendChat() {
        var t = input.text.trim(); if (t === "") return;
        input.text = "";
        chatModel.append({ who: "user", text: t });
        var req = new XMLHttpRequest();
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                var r = "（喵脑还没连上，稍等一下）";
                try { r = JSON.parse(req.responseText).reply; } catch (e) {}
                chatModel.append({ who: "neko", text: r });
            }
        };
        req.open("POST", chatUrl);
        req.setRequestHeader("Content-Type", "application/json");
        req.send(JSON.stringify({ message: t }));
    }

    Plasma5Support.DataSource {
        id: statusSource
        engine: "executable"
        connectedSources: []
        interval: root.refreshMs
        property string command: "cat $HOME/.config/neko-desktop/state/status.json 2>/dev/null || echo '{}'"
        function refresh() { connectSource(command); }
        onNewData: {
            var out = data[command] ? data[command]["stdout"] : "";
            if (out && out !== "{}") { try { root.update(JSON.parse(out)); } catch (e) {} }
            disconnectSource(command);
        }
        Component.onCompleted: refresh()
    }
    Timer { interval: root.refreshMs; running: true; repeat: true; onTriggered: statusSource.refresh() }

    CompactRepresentation {
        id: compactComp
        Row {
            spacing: 4
            Text { text: "🐾"; font.pixelSize: 12 }
            Text {
                text: "Neko · " + (root.status.personality && root.status.personality.mood ? root.status.personality.mood : (root.status.mode || "normal"))
                color: "#ffd6e8"; font.pixelSize: 11
            }
        }
    }

    FullRepresentation {
        id: fullComp
        ColumnLayout {
            spacing: 7
            Layout.preferredWidth: 280

            Message { status: root.status; Layout.fillWidth: true }
            Status { status: root.status; Layout.fillWidth: true }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#33ffd6e8" }

            // 聊天显示区
            ListView {
                id: chatView
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                model: chatModel
                clip: true
                spacing: 2
                delegate: Text {
                    width: chatView.width
                    text: (model.who === "user" ? "⚘ 你：" : "🐱 ") + model.text
                    color: model.who === "user" ? "#ffaad6" : "#f0dfe8"
                    font.pixelSize: 10.5
                    wrapMode: Text.WordWrap
                }
            }

            // 输入框
            Row {
                Layout.fillWidth: true
                spacing: 5
                Rectangle {
                    width: parent.width - 50; height: 26; radius: 7; color: "#22000000"; border.color: "#44ff8cc6"
                    TextInput {
                        id: input
                        anchors.fill: parent; anchors.margins: 5
                        color: "#fff"; font.pixelSize: 11; clip: true
                        Keys.onReturnPressed: sendChat()
                    }
                }
                Rectangle {
                    width: 45; height: 26; radius: 7; color: "#ff8cc6"
                    Text { anchors.centerIn: parent; text: "发送"; color: "#1a0f1a"; font.pixelSize: 11; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: sendChat() }
                }
            }
        }
    }
}
