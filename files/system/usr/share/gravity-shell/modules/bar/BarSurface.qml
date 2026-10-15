import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// What the bar looks like: a solid Material 3 Expressive style strip with inverted corners
// curving down into the screen at both ends: the workspaces floating on the left, the clock
// and date in an accent pill in the middle, and at the right end volume and battery in a
// tonal pill that opens the quick panel. Used by the bar window, and by the
// wallpaper picker, which draws an identical live copy it can slide off the screen.
Item {
    id: root

    // Output name, for the workspaces on it.
    required property string output
    // Window that tray menus open from.
    property var barWindow: null
    // The strip itself, without the corners (for input masks).
    readonly property Item strip: bar

    implicitHeight: Theme.barHeight + Theme.barCorner

    Rectangle {
        id: bar

        width: parent.width
        height: Theme.barHeight
        color: Theme.surface

        Behavior on color {
            ColorAnimation {
                duration: Theme.normal
            }
        }

        Workspaces {
            id: workspaces

            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            output: root.output
        }

        // Focused window title, between the workspaces and the clock.
        FloatText {
            anchors.left: workspaces.right
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, clockPill.x - x - 16))
            height: parent.height
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.DemiBold
            text: ToplevelManager.activeToplevel?.title ?? ""
        }

        Pill {
            id: clockPill

            anchors.centerIn: parent
            color: Theme.gold

            Clock {
                color: Theme.goldInk
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Tray {
                anchors.verticalCenter: parent.verticalCenter
                barWindow: root.barWindow
            }

            // Volume and battery at the far right. Click for the quick panel; scroll
            // for the volume.
            Item {
                id: status

                readonly property bool active: Panels.quick === root.output

                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: statusPill.implicitWidth
                implicitHeight: statusPill.implicitHeight

                Pill {
                    id: statusPill

                    anchors.fill: parent
                    color: statusMouse.containsMouse && !status.active ? Qt.lighter(Theme.dusk, 1.2) : Theme.dusk
                    border.width: status.active ? 2 : 0
                    border.color: Theme.gold

                    Row {
                        spacing: 14

                        Volume {
                            id: volume

                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Battery {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                MouseArea {
                    id: statusMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.toggleQuick(root.output)
                    onWheel: wheel => volume.setVolume(volume.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }
        }
    }

    InvertedCorner {
        x: 0
        y: bar.height
        size: Theme.barCorner
        fill: bar.color
    }

    InvertedCorner {
        x: root.width - Theme.barCorner
        y: bar.height
        size: Theme.barCorner
        fill: bar.color
        mirrored: true
    }

    // A fully rounded tonal container around its content.
    component Pill: Rectangle {
        default property alias content: inner.data

        implicitWidth: inner.childrenRect.width + 28
        implicitHeight: 32
        radius: height / 2

        Behavior on color {
            ColorAnimation {
                duration: Theme.normal
            }
        }

        Item {
            id: inner

            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height
        }
    }
}
