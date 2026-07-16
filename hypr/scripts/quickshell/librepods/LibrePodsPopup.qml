import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    focus: true

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color blue: _theme.blue
    readonly property color teal: _theme.teal
    readonly property color green: _theme.green
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color red: _theme.red

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers"
    readonly property string librepodsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/librepods"
    readonly property string ctlBin: Quickshell.env("HOME") + "/librepods/linux/build/librepods-ctl"

    property bool podsActive: false
    property bool podsConnected: false
    property string deviceName: "AirPods"
    property string deviceAddress: ""
    property string noiseMode: "off"
    property bool disconnecting: false
    property int leftBat: 0
    property int rightBat: 0
    property int caseBat: 0
    property bool leftCharging: false
    property bool rightCharging: false
    property bool caseCharging: false
    property bool leftAvailable: false
    property bool rightAvailable: false
    property bool caseAvailable: false

    function applyStatus(data) {
        window.podsActive = !!data.active;
        window.podsConnected = !!data.connected;
        window.deviceName = data.name || "AirPods";
        window.deviceAddress = data.address || "";
        window.noiseMode = data.noise || "off";
        if (!window.podsConnected && !window.podsActive)
            window.disconnecting = false;
        window.leftBat = data.left || 0;
        window.rightBat = data.right || 0;
        window.caseBat = data.case || 0;
        window.leftCharging = !!data.left_charging;
        window.rightCharging = !!data.right_charging;
        window.caseCharging = !!data.case_charging;
        window.leftAvailable = !!data.left_available;
        window.rightAvailable = !!data.right_available;
        window.caseAvailable = !!data.case_available;
    }

    function setNoise(mode) {
        window.noiseMode = mode;
        noiseSetter.command = [window.ctlBin, "noise:" + mode];
        noiseSetter.running = true;
        statusRefresh.restart();
    }

    function disconnectPods() {
        if (window.disconnecting) return;
        window.disconnecting = true;
        // Optimistically leave AirPods mode so the top-bar swaps to Bluetooth
        window.podsActive = false;
        window.podsConnected = false;
        if (window.deviceAddress && window.deviceAddress.length > 0)
            disconnectProc.command = ["bash", window.librepodsDir + "/disconnect.sh", window.deviceAddress];
        else
            disconnectProc.command = ["bash", window.librepodsDir + "/disconnect.sh"];
        disconnectProc.running = true;
        statusRefresh.restart();
    }

    function batColor(pct) {
        if (pct <= 15) return window.red;
        if (pct <= 30) return window.peach;
        if (pct <= 50) return window.yellow;
        return window.green;
    }

    Process {
        id: statusPoller
        running: true
        command: ["bash", window.scriptsDir + "/librepods_fetch.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (!txt) return;
                try { window.applyStatus(JSON.parse(txt)); } catch (e) { console.warn(e); }
            }
        }
    }

    Timer {
        id: statusRefresh
        interval: 1200
        repeat: false
        onTriggered: statusPoller.running = true
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: statusPoller.running = true
    }

    Process { id: noiseSetter; running: false }
    Process {
        id: disconnectProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: statusRefresh.restart()
        }
        onExited: {
            window.disconnecting = false;
            window.podsActive = false;
            window.podsConnected = false;
            statusPoller.running = true;
            // Close this popup; bar pill will show Bluetooth again
            Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh close"]);
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: window.s(22)
        color: Qt.rgba(window.mantle.r, window.mantle.g, window.mantle.b, 0.94)
        border.width: 1
        border.color: Qt.rgba(window.surface2.r, window.surface2.g, window.surface2.b, 0.55)
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: window.s(22)
            spacing: window.s(16)

            RowLayout {
                Layout.fillWidth: true
                spacing: window.s(12)

                Text {
                    text: "󱡏"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: window.s(28)
                    color: window.podsActive ? window.mauve : window.subtext0
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: window.s(2)

                    Text {
                        text: window.deviceName
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(16)
                        font.weight: Font.Black
                        color: window.text
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: window.podsConnected ? "Connected" : (window.podsActive ? "Nearby / BLE" : "Disconnected")
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(12)
                        color: window.podsConnected ? window.green : window.subtext0
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(window.surface2.r, window.surface2.g, window.surface2.b, 0.6)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: window.s(10)

                Repeater {
                    model: [
                        { key: "L", label: "Left", level: window.leftBat, charging: window.leftCharging, available: window.leftAvailable },
                        { key: "R", label: "Right", level: window.rightBat, charging: window.rightCharging, available: window.rightAvailable },
                        { key: "C", label: "Case", level: window.caseBat, charging: window.caseCharging, available: window.caseAvailable }
                    ]

                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: window.s(10)
                        opacity: modelData.available ? 1.0 : 0.35

                        Rectangle {
                            width: window.s(28)
                            height: window.s(28)
                            radius: window.s(8)
                            color: window.surface0
                            Text {
                                anchors.centerIn: parent
                                text: modelData.key
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                font.pixelSize: window.s(12)
                                color: window.text
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: window.s(4)

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.label
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: window.s(12)
                                    font.weight: Font.Bold
                                    color: window.subtext0
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: (modelData.available ? modelData.level + "%" : "—") + (modelData.charging ? " 󰚥" : "")
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: window.s(12)
                                    font.weight: Font.Black
                                    color: modelData.available ? window.batColor(modelData.level) : window.overlay0
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: window.s(8)
                                radius: window.s(4)
                                color: window.surface0

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, (modelData.available ? modelData.level : 0) / 100.0))
                                    height: parent.height
                                    radius: parent.radius
                                    color: window.batColor(modelData.level)
                                    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                text: "Noise Control"
                font.family: "JetBrains Mono"
                font.pixelSize: window.s(12)
                font.weight: Font.Bold
                color: window.subtext0
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: window.s(8)

                Repeater {
                    model: [
                        { id: "off", label: "Off", icon: "󰟎" },
                        { id: "transparency", label: "Trans", icon: "󰓃" },
                        { id: "adaptive", label: "Adapt", icon: "󰥰" },
                        { id: "anc", label: "ANC", icon: "󰋋" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(64)
                        radius: window.s(14)
                        property bool selected: window.noiseMode === modelData.id
                        property bool hovered: modeMa.containsMouse

                        color: selected ? window.mauve : (hovered ? window.surface1 : window.surface0)
                        border.width: 1
                        border.color: selected ? Qt.lighter(window.mauve, 1.2) : window.surface2
                        opacity: window.podsConnected ? 1.0 : 0.55
                        Behavior on color { ColorAnimation { duration: 180 } }
                        scale: modeMa.pressed ? 0.96 : (hovered ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        Column {
                            anchors.centerIn: parent
                            spacing: window.s(4)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: window.s(18)
                                color: selected ? window.crust : window.text
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(11)
                                font.weight: Font.Black
                                color: selected ? window.crust : window.text
                            }
                        }

                        MouseArea {
                            id: modeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.setNoise(modelData.id)
                        }
                    }
                }
            }

            Text {
                visible: !window.podsConnected
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: window.podsActive
                    ? "Battery via BLE. Connect AirPods fully to change noise modes."
                    : "Waiting for LibrePods / AirPods…"
                font.family: "JetBrains Mono"
                font.pixelSize: window.s(11)
                color: window.overlay0
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(44)
                radius: window.s(12)
                visible: window.podsConnected || window.podsActive || window.disconnecting
                property bool hovered: discMa.containsMouse
                color: hovered ? Qt.rgba(window.red.r, window.red.g, window.red.b, 0.28) : window.surface0
                border.width: 1
                border.color: window.red
                opacity: window.disconnecting ? 0.6 : 1.0
                Behavior on color { ColorAnimation { duration: 160 } }
                scale: discMa.pressed ? 0.97 : (hovered ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Row {
                    anchors.centerIn: parent
                    spacing: window.s(8)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰂲"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(16)
                        color: window.red
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: window.disconnecting ? "Disconnecting…" : "Disconnect"
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(13)
                        font.weight: Font.Black
                        color: window.red
                    }
                }

                MouseArea {
                    id: discMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !window.disconnecting
                    onClicked: window.disconnectPods()
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
