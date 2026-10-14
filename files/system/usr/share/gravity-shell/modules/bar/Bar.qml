import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// A levitating island bar. It drops in from above on login and sways when gravity shifts.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        color: "transparent"
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 62
        exclusiveZone: 50
        WlrLayershell.namespace: "gravity-bar"
        WlrLayershell.layer: WlrLayer.Top

        // Only the island itself takes clicks; the shadow margin around it stays click-through.
        mask: Region {
            item: island
        }

        property point g: Qt.point(0, 0)

        FrameAnimation {
            running: Gravity.active
            onTriggered: win.g = Gravity.offsetAt(Gravity.now())
            onRunningChanged: if (!running)
                win.g = Qt.point(0, 0)
        }

        Rectangle {
            id: island

            x: 12 + win.g.x * 10
            width: parent.width - 24
            height: 40
            radius: 20
            color: Theme.panel
            border.color: Theme.panelBorder
            border.width: 1
            rotation: win.g.x * 0.35

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0.02, 0, 0.08, 0.7)
                shadowBlur: 0.8
                shadowVerticalOffset: 4
            }

            // Falls in with gravity and bounces once before floating.
            SequentialAnimation on y {
                PropertyAction {
                    value: -60
                }
                PauseAnimation {
                    duration: 500
                }
                NumberAnimation {
                    to: 8
                    duration: 900
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.4
                }
            }

            transform: Translate {
                y: win.g.y * 6
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 16
                spacing: 14

                Gem {
                    size: 18
                    spinning: Config.animatedBackground
                    Layout.alignment: Qt.AlignVCenter
                }

                Workspaces {
                    output: win.modelData.name
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                }

                Tray {
                    barWindow: win
                    Layout.alignment: Qt.AlignVCenter
                }

                Volume {
                    Layout.alignment: Qt.AlignVCenter
                }

                Battery {
                    Layout.alignment: Qt.AlignVCenter
                }

                Clock {
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Focused window title, centred on the island.
            FloatText {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, island.width * 0.36)
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                color: Theme.textDim
                text: ToplevelManager.activeToplevel?.title ?? ""
            }
        }
    }
}
