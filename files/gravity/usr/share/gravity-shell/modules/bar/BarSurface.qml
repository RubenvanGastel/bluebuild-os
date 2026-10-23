import QtQuick
import Quickshell.Wayland
import qs.services
import qs.components

// What the bar looks like: a solid Material 3 Expressive style strip along one screen edge
// (Theme.barEdge) with inverted corners curving into the screen at both ends: the workspaces
// floating at the start, the clock and date in an accent pill in the middle with an audio
// visualiser beside it while something can play, and at the far
// end the tray, the system monitor, the battery, and network, Bluetooth and volume in a
// tonal pill that opens the quick panel. Along a side everything stacks vertically. Config.bar* hide parts of it.
// Theme.barStyle "floating" makes it a fully rounded bar inset from the edge, "frame" adds a
// thin border around the rest of the screen with the corners curving in at all four.
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
    readonly property bool floating: Theme.barStyle === "floating"
    readonly property bool frame: Theme.barStyle === "frame"
    readonly property real inset: Theme.barInset
    readonly property real frameSize: Theme.frameSize
    // Along the bar and across the screen from its edge.
    readonly property real length: vertical ? height : width
    readonly property real across: vertical ? width : height
    // Size of the bar window: the strip and the corners curving away from it (the whole
    // screen with the frame).
    readonly property int depth: frame ? Theme.barSize : inset + Theme.barSize + (floating ? 0 : Theme.barCorner)

    Rectangle {
        id: bar

        x: root.edge === "right" ? root.width - width - root.inset : root.inset
        y: root.edge === "bottom" ? root.height - height - root.inset : root.inset
        width: root.vertical ? Theme.barSize : root.width - 2 * root.inset
        height: root.vertical ? root.height - 2 * root.inset : Theme.barSize
        radius: root.floating ? Theme.barSize / 2 : 0
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

        // Audio visualiser just after the clock, with a small play/pause button at its end,
        // while there is a media player. It fades and grows in when one appears and fades
        // out when it goes. Click (anywhere but the button) for the media panel under it.
        Item {
            id: media

            readonly property bool active: Panels.media === root.output
            readonly property bool shown: Config.barMedia && Playback.hasPlayer
            // Where the clock ends (the middle of the bar without it).
            readonly property real after: root.vertical ? (clockPill.visible ? clockPill.y + clockPill.height : parent.height / 2) : (clockPill.visible ? clockPill.x + clockPill.width : parent.width / 2)
            // Middle of the pill along the bar, where the panel opens; as the monitor's.
            readonly property real centre: !shown ? -1 : root.vertical ? bar.y + y + height / 2 : bar.x + x + width / 2

            onCentreChanged: if (root.enabled)
                Panels.setMediaAnchor(root.output, centre)
            Component.onCompleted: if (root.enabled)
                Panels.setMediaAnchor(root.output, centre)

            visible: opacity > 0
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.8
            x: root.vertical ? (parent.width - width) / 2 : after + 10
            y: root.vertical ? after + 10 : (parent.height - height) / 2
            // The visualiser, then the button close to the pill's rounded end.
            width: root.vertical ? 34 : 14 + mediaContent.width + 4
            height: root.vertical ? 12 + mediaContent.height + 4 : 32

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.normal
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.normal
                    easing.type: media.shown ? Easing.OutBack : Easing.InCubic
                }
            }

            // Under the pill's contents, so the button takes its own clicks.
            MouseArea {
                id: mediaMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggleMedia(root.output)
            }

            Rectangle {
                anchors.fill: parent
                radius: (root.vertical ? width : height) / 2
                color: mediaMouse.containsMouse && !media.active ? Theme.hover(Theme.dusk, 1.2) : Theme.dusk
                border.width: media.active ? 2 : 0
                border.color: Theme.gold

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.normal
                    }
                }

                Grid {
                    id: mediaContent

                    x: root.vertical ? (parent.width - width) / 2 : 14
                    y: root.vertical ? 12 : (parent.height - height) / 2
                    columns: root.vertical ? 1 : 2
                    spacing: 8
                    horizontalItemAlignment: Grid.AlignHCenter
                    verticalItemAlignment: Grid.AlignVCenter

                    Visualizer {
                        vertical: root.vertical
                    }

                    // Play/pause, in the accent.
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: playMouse.containsMouse ? Theme.hover(Theme.gold, 1.12) : Theme.gold
                        scale: playMouse.pressed ? 0.88 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.fast
                                easing.type: Easing.OutBack
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.fast
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            // The play triangle sits a touch right of centre to look centred.
                            anchors.horizontalCenterOffset: Playback.playing ? 0 : 1
                            text: Playback.playing ? "\u{f03e4}" : "\u{f040a}"
                            color: Theme.goldInk
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: playMouse

                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: Playback.player?.canTogglePlaying ?? false
                            onClicked: Playback.player.togglePlaying()
                        }
                    }
                }
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

            Tray {
                visible: Config.barTray
                vertical: root.vertical
                barWindow: root.barWindow
            }

            // CPU and memory bars. Click for the monitor panel under it.
            Item {
                id: stats

                readonly property bool active: Panels.monitor === root.output
                // Middle of the pill along the bar, where the panel opens from Mod+M too
                // (at the far end while it's hidden). Not from the wallpaper picker's copy
                // of the bar.
                readonly property real centre: !Config.barStats ? 1e6 : root.vertical ? bar.y + end.y + y + height / 2 : bar.x + end.x + x + width / 2

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

            // Battery level, on laptops. Click for the battery panel under it.
            Item {
                id: power

                readonly property bool active: Panels.battery === root.output
                // Middle of the pill along the bar, where the panel opens; as the monitor's.
                readonly property real centre: !visible ? 1e6 : root.vertical ? bar.y + end.y + y + height / 2 : bar.x + end.x + x + width / 2

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

    // Curving into the screen at both ends of the bar (into the frame with one).
    EdgeCorner {
        visible: !root.floating
        u: root.frameSize
        v: Theme.barSize
        size: Theme.barCorner
        fill: bar.color
    }

    EdgeCorner {
        visible: !root.floating
        u: root.length - root.frameSize - size
        v: Theme.barSize
        size: Theme.barCorner
        high: true
        fill: bar.color
    }

    // The frame: along both ends of the bar and the far edge, curving in at the far corners.
    Band {
        u: 0
        v: Theme.barSize
        along: root.frameSize
        thickness: root.across - Theme.barSize
    }

    Band {
        u: root.length - root.frameSize
        v: Theme.barSize
        along: root.frameSize
        thickness: root.across - Theme.barSize
    }

    Band {
        u: root.frameSize
        v: root.across - root.frameSize
        along: root.length - 2 * root.frameSize
        thickness: root.frameSize
    }

    EdgeCorner {
        visible: root.frame
        u: root.frameSize
        v: root.across - root.frameSize - size
        size: Theme.barCorner
        near: false
        fill: bar.color
    }

    EdgeCorner {
        visible: root.frame
        u: root.length - root.frameSize - size
        v: root.across - root.frameSize - size
        size: Theme.barCorner
        near: false
        high: true
        fill: bar.color
    }

    // A strip of the frame in the bar's terms (as EdgeCorner): `along` from `u`, `thickness`
    // from `v` away from the bar's edge. Its parent must cover the whole screen.
    component Band: Rectangle {
        property real u
        property real v
        property real along
        property real thickness

        readonly property string edge: Theme.barEdge

        visible: Theme.barStyle === "frame"
        x: edge === "left" ? v : edge === "right" ? parent.width - v - thickness : u
        y: edge === "top" ? v : edge === "bottom" ? parent.height - v - thickness : u
        width: Theme.barVertical ? thickness : along
        height: Theme.barVertical ? along : thickness
        color: Theme.surface

        Behavior on color {
            ColorAnimation {
                duration: Theme.normal
            }
        }
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
