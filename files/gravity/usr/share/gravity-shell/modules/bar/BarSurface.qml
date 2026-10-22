import QtQuick
import Quickshell.Wayland
import qs.services
import qs.components

// What the bar looks like: a solid Material 3 Expressive style strip along one screen edge
// (Theme.barEdge) with inverted corners curving into the screen at both ends: the workspaces
// floating at the start, the clock and date in an accent pill in the middle, and at the far
// end the system monitor, the tray, the battery, and network, Bluetooth and volume in a
// tonal pill that opens the quick panel. Along a side everything stacks vertically. Config.bar* hide parts of it.
// Fill the area the bar is drawn in with it: the bar window, or the wallpaper picker, which
// draws an identical live copy of the screen it can slide away.
Item {
    id: root

    // Output name, for the workspaces on it.
    required property string output
    // Window that tray menus open from.
    property var barWindow: null
    // The strip itself, without the corners (for input masks).
    readonly property Item strip: bar

    readonly property string edge: Theme.barEdge
    readonly property bool vertical: Theme.barVertical
    // Size of the bar window: the strip and the corners curving away from it.
    readonly property int depth: Theme.barSize + Theme.barCorner

    Rectangle {
        id: bar

        x: root.edge === "right" ? root.width - width : 0
        y: root.edge === "bottom" ? root.height - height : 0
        width: root.vertical ? Theme.barSize : root.width
        height: root.vertical ? root.height : Theme.barSize
        color: Theme.surface

        Behavior on color {
            ColorAnimation {
                duration: Theme.normal
            }
        }

        Workspaces {
            id: workspaces

            visible: Config.barWorkspaces && hasWorkspaces
            vertical: root.vertical
            x: root.vertical ? (parent.width - width) / 2 : 16
            y: root.vertical ? 16 : (parent.height - height) / 2
            output: root.output
        }

        // Focused window title, between the workspaces and the clock. Not along a side.
        FloatText {
            readonly property real from: workspaces.visible ? workspaces.x + workspaces.width + 16 : 16

            visible: Config.barTitle && !root.vertical
            x: from
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, (clockPill.visible ? clockPill.x : end.x) - from - 16))
            height: parent.height
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.DemiBold
            text: ToplevelManager.activeToplevel?.title ?? ""
        }

        Pill {
            id: clockPill

            visible: Config.barClock
            vertical: root.vertical
            anchors.centerIn: parent
            color: Theme.gold

            Clock {
                color: Theme.goldInk
                vertical: root.vertical
            }
        }

        Grid {
            id: end

            x: root.vertical ? (parent.width - width) / 2 : parent.width - width - 6
            y: root.vertical ? parent.height - height - 6 : (parent.height - height) / 2
            columns: root.vertical ? 1 : 100
            spacing: 12
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            // CPU and memory bars. Click for the monitor panel under it.
            Item {
                id: stats

                readonly property bool active: Panels.monitor === root.output
                // Middle of the pill along the bar, where the panel opens from Mod+M too
                // (at the far end while it's hidden). Not from the wallpaper picker's copy
                // of the bar.
                readonly property real centre: !Config.barStats ? 1e6 : root.vertical ? end.y + y + height / 2 : end.x + x + width / 2

                onCentreChanged: if (root.enabled)
                    Panels.setMonitorAnchor(root.output, centre)
                Component.onCompleted: if (root.enabled)
                    Panels.setMonitorAnchor(root.output, centre)

                visible: Config.barStats
                implicitWidth: statsPill.implicitWidth
                implicitHeight: statsPill.implicitHeight

                Pill {
                    id: statsPill

                    vertical: root.vertical
                    anchors.fill: parent
                    color: statsMouse.containsMouse && !stats.active ? Theme.hover(Theme.dusk, 1.2) : Theme.dusk
                    border.width: stats.active ? 2 : 0
                    border.color: Theme.gold

                    SysStats {
                        vertical: root.vertical
                    }
                }

                MouseArea {
                    id: statsMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.toggleMonitor(root.output)
                }
            }

            Tray {
                visible: Config.barTray
                vertical: root.vertical
                barWindow: root.barWindow
            }

            // Battery level, on laptops. Click for the battery panel under it.
            Item {
                id: power

                readonly property bool active: Panels.battery === root.output
                // Middle of the pill along the bar, where the panel opens; as the monitor's.
                readonly property real centre: !visible ? 1e6 : root.vertical ? end.y + y + height / 2 : end.x + x + width / 2

                onCentreChanged: if (root.enabled)
                    Panels.setBatteryAnchor(root.output, centre)
                Component.onCompleted: if (root.enabled)
                    Panels.setBatteryAnchor(root.output, centre)

                visible: Config.barBattery && battery.available
                implicitWidth: powerPill.implicitWidth
                implicitHeight: powerPill.implicitHeight

                Pill {
                    id: powerPill

                    vertical: root.vertical
                    anchors.fill: parent
                    color: powerMouse.containsMouse && !power.active ? Theme.hover(Theme.dusk, 1.2) : Theme.dusk
                    border.width: power.active ? 2 : 0
                    border.color: Theme.gold

                    Battery {
                        id: battery

                        vertical: root.vertical
                    }
                }

                MouseArea {
                    id: powerMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.toggleBattery(root.output)
                }
            }

            // Network, Bluetooth and volume at the far end. Click for the quick panel; scroll
            // for the volume.
            Item {
                id: status

                readonly property bool active: Panels.quick === root.output

                visible: Config.barStatus
                implicitWidth: statusPill.implicitWidth
                implicitHeight: statusPill.implicitHeight

                Pill {
                    id: statusPill

                    vertical: root.vertical
                    anchors.fill: parent
                    color: statusMouse.containsMouse && !status.active ? Theme.hover(Theme.dusk, 1.2) : Theme.dusk
                    border.width: status.active ? 2 : 0
                    border.color: Theme.gold

                    Grid {
                        columns: root.vertical ? 1 : 3
                        spacing: root.vertical ? 10 : 12
                        horizontalItemAlignment: Grid.AlignHCenter
                        verticalItemAlignment: Grid.AlignVCenter

                        Network {}

                        BluetoothStatus {}

                        Volume {
                            id: volume
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

    // Curving into the screen at both ends of the bar.
    EdgeCorner {
        u: 0
        v: Theme.barSize
        size: Theme.barCorner
        fill: bar.color
    }

    EdgeCorner {
        u: (root.vertical ? root.height : root.width) - size
        v: Theme.barSize
        size: Theme.barCorner
        high: true
        fill: bar.color
    }

    // A fully rounded tonal container around its content: as tall as the bar is thick
    // allows, along a side as wide.
    component Pill: Rectangle {
        property bool vertical: false
        default property alias content: inner.data

        implicitWidth: vertical ? 34 : inner.childrenRect.width + 28
        implicitHeight: vertical ? inner.childrenRect.height + 22 : 32
        radius: (vertical ? width : height) / 2

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
