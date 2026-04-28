import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var island

    Item {
        anchors.fill: parent
        anchors.margins: island.s(24)
        anchors.bottomMargin: island.s(72)

        ColumnLayout {
            anchors.fill: parent
            spacing: island.s(12)

            RowLayout {
                Layout.fillWidth: true
                spacing: island.s(12)

                Rectangle {
                    Layout.preferredWidth: island.s(52)
                    Layout.preferredHeight: island.s(52)
                    radius: island.s(14)
                    color: Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.2)
                    border.width: 1
                    border.color: Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.45)

                    Text {
                        anchors.centerIn: parent
                        text: "󰖟"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: island.s(28)
                        color: island.mauve
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: island.s(2)

                    Text {
                        text: "Brave"
                        font.family: "JetBrains Mono"
                        font.pixelSize: island.s(13)
                        font.weight: Font.Black
                        color: island.mauve
                    }

                    Text {
                        text: "Most visited websites"
                        font.family: "JetBrains Mono"
                        font.pixelSize: island.s(10)
                        color: island.subtext0
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(island.text.r, island.text.g, island.text.b, 0.08)
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: island.s(10)
                columnSpacing: island.s(10)

                Repeater {
                    model: island.topSites
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: island.s(64)
                        radius: island.s(12)
                        color: siteMouse.containsMouse
                            ? Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.2)
                            : Qt.rgba(island.surface0.r, island.surface0.g, island.surface0.b, 0.55)
                        border.width: 1
                        border.color: siteMouse.containsMouse
                            ? Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.5)
                            : Qt.rgba(island.surface1.r, island.surface1.g, island.surface1.b, 0.55)

                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: island.s(10)
                            spacing: island.s(2)

                            Text {
                                text: title || host || ""
                                font.family: "JetBrains Mono"
                                font.pixelSize: island.s(11)
                                font.weight: Font.Black
                                color: island.text
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: host || ""
                                font.family: "JetBrains Mono"
                                font.pixelSize: island.s(9)
                                color: island.subtext0
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
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

                Item {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: island.topSites.count === 0

                    Text {
                        anchors.centerIn: parent
                        text: "No browsing history available yet"
                        font.family: "JetBrains Mono"
                        font.pixelSize: island.s(12)
                        color: island.subtext0
                    }
                }
            }
        }
    }
}
