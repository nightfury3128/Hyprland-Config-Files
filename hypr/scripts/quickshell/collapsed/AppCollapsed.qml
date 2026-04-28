import QtQuick
import QtQuick.Layouts
Row {
    property var island
    property int preferredWidth: {
        let max = Screen.width - island.s(32);
        return Math.min(island.s(560), max);
    }
    spacing: island.s(10)

    Rectangle {
        width: island.s(28); height: island.s(28); radius: island.s(8)
        color: Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.18)
        border.width: 1
        border.color: Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.45)
        anchors.verticalCenter: parent.verticalCenter

        Text {
            anchors.centerIn: parent
            text: "󰖟"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: island.s(15)
            color: island.mauve
        }
    }

    ColumnLayout {
        spacing: 0
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: "Brave"
            font.family: "JetBrains Mono"
            font.pixelSize: island.s(12)
            font.weight: Font.Black
            color: island.mauve
            Layout.maximumWidth: island.s(96)
            elide: Text.ElideRight
        }
        Text {
            text: "Sites"
            font.family: "JetBrains Mono"
            font.pixelSize: island.s(10)
            font.weight: Font.Bold
            color: island.subtext0
            Layout.maximumWidth: island.s(96)
            elide: Text.ElideRight
        }
    }

    Row {
        spacing: island.s(8)
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: island.topSites
            delegate: Rectangle {
                width: island.s(126)
                height: island.s(28)
                radius: island.s(14)
                color: siteMouse.containsMouse
                    ? Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.24)
                    : Qt.rgba(island.surface0.r, island.surface0.g, island.surface0.b, 0.65)
                border.width: 1
                border.color: siteMouse.containsMouse
                    ? Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.55)
                    : Qt.rgba(island.surface1.r, island.surface1.g, island.surface1.b, 0.45)

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    text: title || host || ""
                    font.family: "JetBrains Mono"
                    font.pixelSize: island.s(10)
                    font.weight: Font.Bold
                    color: island.text
                    elide: Text.ElideRight
                    width: parent.width - island.s(14)
                    horizontalAlignment: Text.AlignHCenter
                }

                MouseArea {
                    id: siteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: island.openUrl(url)
                }
            }
        }
    }
}
