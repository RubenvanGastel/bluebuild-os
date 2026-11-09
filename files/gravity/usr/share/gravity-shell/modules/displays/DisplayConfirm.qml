import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.settings

// While a display change waits to be kept (Displays.confirming): a card on every screen
// asking to keep it, counting down to going back. On every screen, as the one the
// settings were on may be the one that went dark, and the others may be new.
Variants {
    model: Displays.confirming ? Quickshell.screens : []

    PanelWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        color: "transparent"
        anchors.top: true
        margins.top: Theme.barOuter + Theme.gap * 2
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: card.width + 48
        implicitHeight: card.height + 48
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "gravity-display-confirm"
        BackgroundEffect.blurRegion: Region {
            item: Theme.blur ? card : null
            radius: card.radius
        }

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: row.implicitWidth + 40
            height: row.implicitHeight + 28
            radius: height / 2
            color: Theme.surface

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: !Theme.blur
                shadowColor: Qt.rgba(0, 0, 0, 0.45)
                shadowBlur: 0.6
                shadowVerticalOffset: 4
            }

            Row {
                id: row

                anchors.centerIn: parent
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{f0379}"
                    color: Theme.gold
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 22
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Keep these display settings? Going back in %1 s", Displays.countdown)
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                PillButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "\u{f054c}"
                    label: I18n.tr("Revert")
                    onClicked: Displays.revert()
                }

                PillButton {
                    anchors.verticalCenter: parent.verticalCenter
                    accent: true
                    icon: "\u{f012c}"
                    label: I18n.tr("Keep")
                    onClicked: Displays.keep()
                }
            }
        }
    }
}
