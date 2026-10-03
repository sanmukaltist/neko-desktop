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
        personality: { banner: "🐱🎀 Neko Desktop", text: "", lines: [] }
    })
    property int refreshMs: plasmoid.configuration.refreshInterval || 3000

    function update(obj) { status = obj; }

    Plasma5Support.DataSource {
        id: statusSource
        engine: "executable"
        connectedSources: []
        interval: root.refreshMs
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
    Timer { interval: root.refreshMs; running: true; repeat: true; onTriggered: statusSource.refresh() }

    CompactRepresentation {
        id: compactComp
        Row {
            spacing: 4
            Text { text: "🐾"; font.pixelSize: 12 }
            Text { text: "Neko · " + (root.status.mode || "normal"); color: "#ffd6e8"; font.pixelSize: 11 }
            Text { text: root.status.network ? "· Online" : "· Offline"; color: root.status.network ? "#a8e6b0" : "#ff8cc6"; font.pixelSize: 11 }
        }
    }

    FullRepresentation {
        id: fullComp
        ColumnLayout {
            spacing: 8
            Layout.preferredWidth: 280

            Message { status: root.status; Layout.fillWidth: true }
            Status { status: root.status; Layout.fillWidth: true }
        }
    }
}
